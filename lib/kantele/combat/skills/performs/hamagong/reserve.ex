defmodule Kantele.Combat.Skills.Performs.Hamagong.Reserve do
  @moduledoc """
  exert「reserve」（source hamagong/reserve.c，inherit F_CLEAN_UP）

  门槛（按 `.c` 顺序）：蛤蟆功>=120 → 真气>=200 → 未倒转经脉。
  扣 100 真气；临时提升 `dodge`/`parry` 各 `蛤蟆功/3`、`armor`/`dispel_poison`
  各 `蛤蟆功/2`；战斗中忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `set_temp("hmg_dzjm", skill)` 折算为引擎 buff
    （`Buff{key: "hmg_dzjm", applies: 各加成的负值}`），既作 `hui` 的回收依据，
    也作「是否已倒转经脉」的门槛；`.c` 无 `start_call_out`，该 buff 不自动到期；
  - `apply/dispel_poison` 不在 `Combat.applies_keys/0` 白名单内（引擎未建模），
    仅随 `apply_temp/2` 一并记录，无读取方。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @key "hmg_dzjm"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("hamagong", 1) < 120)
  #        return notify_fail("你的蛤蟆功不够娴熟，不会经脉倒转。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "hamagong") < 120 do
      {:error, "你的蛤蟆功不够娴熟，不会经脉倒转。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200) return notify_fail("你现在的真气不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("hmg_dzjm")) return notify_fail("你已经倒转经脉了。\n");
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经倒转经脉了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: skill = me->query_skill("hamagong", 1);
    #      msg = HIB "$N" HIB "忽地双手撑地倒立，逆运经脉，顿时"
    #            "内息暗生，防御力大增。\n" NOR;
    #      message_combatd(msg, me);
    #      me->add_temp("apply/dodge", skill / 3);
    #      me->add_temp("apply/parry", skill / 3);
    #      me->add_temp("apply/armor", skill / 2);
    #      me->add_temp("apply/dispel_poison", skill / 2);
    #      me->set_temp("hmg_dzjm", skill);
    #      me->add("neili", -100);
    #      if (me->is_fighting()) me->start_busy(2);
    skill = Stats.skill(character.meta.stats, "hamagong")

    applies = %{
      dodge: div(skill, 3),
      parry: div(skill, 3),
      armor: div(skill, 2),
      dispel_poison: div(skill, 2)
    }

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(%Buff{key: @key, applies: negate(applies)})
      |> start_busy_if_fighting(2)

    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

    conn
    |> Broadcast.publish("$N忽地双手撑地倒立，逆运经脉，顿时内息暗生，防御力大增。\n",
      n1: character.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp start_busy_if_fighting(combat, rounds) do
    if Combat.fighting?(combat), do: Combat.start_busy(combat, rounds), else: combat
  end

  # 到期/回收按负值抵消（与 `Performs.Simple` 的 `{:buff, ...}` 一致）。
  defp negate(applies), do: Map.new(applies, fn {key, value} -> {key, -value} end)
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // reserve.c 蛤蟆功经脉倒转
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int a_amount);
  # 
  # int exert(object me, object target)
  # {
  #         // object weapon;
  #         int skill;
  #         string msg;
  # 
  #         if ((int)me->query_skill("hamagong", 1) < 120)
  #                 return notify_fail("你的蛤蟆功不够娴熟，不会经脉倒转。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够。\n");
  # 
  #         if ((int)me->query_temp("hmg_dzjm"))
  #                 return notify_fail("你已经倒转经脉了。\n");
  # 
  #         skill = me->query_skill("hamagong", 1);
  #         msg = HIB "$N" HIB "忽地双手撑地倒立，逆运经脉，顿时"
  #               "内息暗生，防御力大增。\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         me->add_temp("apply/dodge", skill / 3);
  #         me->add_temp("apply/parry", skill / 3);
  #         me->add_temp("apply/armor", skill / 2);
  #         me->add_temp("apply/dispel_poison", skill / 2);
  #         me->set_temp("hmg_dzjm", skill);
  # 
  #         me->add("neili", -100);
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
end

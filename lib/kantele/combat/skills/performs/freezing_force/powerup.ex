defmodule Kantele.Combat.Skills.Performs.FreezingForce.Powerup do
  @moduledoc """
  exert「powerup」（source freezing-force/powerup.c）

  门槛（按 `.c` 顺序）：目标为自身 → 真气>=200 → 未在运功。
  扣 100 真气；`attack`=`defense`=`冰蚕寒功/3`；持续 冰蚕寒功 秒；
  战斗中忙乱 3；到期回收加成。

  差异（TODO(migrate)）：
  - `apply/attack`、`apply/defense` 临时加成与 `set_temp("powerup")` 由引擎 buff
    机制承担（真实运行为 `Kantele.Combat.Skills.FreezingForce.Powerup` 的
    `Performs.Simple` spec，见 `skills/freezing_force.ex`），本文件为并存的对齐副本；
  - `.c` 的 `target != me` 门槛在 exert 语境下恒真，引擎 spec 未单列该门槛，
    此处仅保留文案以对齐 `.c`；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎由 exert 分派统一把关。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

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
    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail("你只能提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 200) return notify_fail("你的真气不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("powerup")) return notify_fail("你已经在运功中了。\n");
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: skill = me->query_skill("freezing-force", 1);
    #      message_combatd(HIW "$N" HIW "脸色一寒，一股煞气腾然而起，四下登时阴风瑟瑟，冷意惨惨。\n" NOR, me);
    #      me->add_temp("apply/attack", skill / 3); me->add_temp("apply/defense", skill / 3);
    #      me->set_temp("powerup", 1); me->add("neili", -100);
    #      me->start_call_out((:call_other, __FILE__, "remove_effect", me, skill / 3), skill);
    #      if (me->is_fighting()) me->start_busy(3);
    skill = Stats.skill(character.meta.stats, "freezing-force")
    gain = div(skill, 3)
    applies = %{attack: gain, defense: gain}

    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(%Buff{key: "powerup", applies: negate(applies)})
      |> start_busy_if_fighting(3)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish("$N脸色一寒，一股煞气腾然而起，四下登时阴风瑟瑟，冷意惨惨。\n",
      n1: character.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp start_busy_if_fighting(combat, rounds) do
    if Combat.fighting?(combat), do: Combat.start_busy(combat, rounds), else: combat
  end

  # 到期回收按负值抵消（与 `Performs.Simple` 的 `{:buff, ...}` 一致）。
  defp negate(applies), do: Map.new(applies, fn {key, value} -> {key, -value} end)

  # LPC remove_effect：tell_object(me, "你的冰蚕寒功运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的冰蚕寒功运行完毕，将内力收回丹田。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c 冰蚕寒功加力
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("freezing-force", 1);
  # 
  #         message_combatd(HIW "$N" HIW "脸色一寒，一股煞气腾然而起，四下登时阴风瑟瑟，冷意惨惨。\n" NOR, me);
  # 
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #         me->set_temp("powerup", 1);
  #         me->add("neili", -100);
  # 
  #         me->start_call_out( (: call_other, __FILE__, "remove_effect", me, skill / 3 :), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", - amount);
  #                 me->add_temp("apply/defense", - amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的冰蚕寒功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end

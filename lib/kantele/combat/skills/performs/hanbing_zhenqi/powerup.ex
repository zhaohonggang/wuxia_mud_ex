defmodule Kantele.Combat.Skills.Performs.HanbingZhenqi.Powerup do
  @moduledoc """
  exert「powerup」（source hanbing-zhenqi/powerup.c）

  门槛（按 `.c` 顺序）：目标为自身 → 内力>=150 → 未在运功。
  扣 100 内力；`attack`=`defense`=`寒冰真气/3`；持续 寒冰真气 秒；
  战斗中忙乱 `1+random(3)`；到期回收加成。

  差异（TODO(migrate)）：
  - `apply/attack`、`apply/defense` 与 `set_temp("powerup")` 由引擎 buff
    机制承担（真实运行为 `Kantele.Combat.Skills.HanbingZhenqi.Powerup` 的
    `Performs.Simple` spec，见 `skills/hanbing_zhenqi.ex`），本文件为并存的对齐副本；
  - `.c` 的 `target != me` 门槛在 exert 语境下恒真，引擎 spec 未单列该门槛，
    此处仅保留文案以对齐 `.c`；
  - `.c` 的 `me->receive_damage("qi", 0)` 伤害为 0、无文案，忽略；
  - `.c` 的 `start_call_out(remove_effect, skill)` 与 `tell_object` 到期文案以
    `@doc false` 的 `expire_message/0` 保留（对齐副本不调度定时器）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @key "powerup"

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

  # LPC: if (target != me) return notify_fail("你只能用寒冰真气来提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能用寒冰真气来提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 150) return notify_fail("你的内力不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("powerup")) return notify_fail("你已经在运功中了。\n");
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: skill = me->query_skill("hanbing-zhenqi", 1);
    #      me->add("neili", -100); me->receive_damage("qi", 0);
    #      message_combatd(HIW "$N" HIW "微一凝神，默默运转体内所蓄的寒"
    #                      "冰真气，霎时面部竟呈出一层薄霜。\n" NOR, me);
    #      me->add_temp("apply/attack", skill / 3);
    #      me->add_temp("apply/defense", skill / 3);
    #      me->set_temp("powerup", 1);
    #      me->start_call_out((:call_other, __FILE__, "remove_effect", me, skill / 3:), skill);
    #      if (me->is_fighting()) me->start_busy(1 + random(3));
    skill = Stats.skill(character.meta.stats, "hanbing-zhenqi")
    gain = div(skill, 3)
    applies = %{attack: gain, defense: gain}

    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(%Buff{key: @key, applies: negate(applies)})
      |> start_busy_if_fighting(1 + Engine.rand(&:rand.uniform/1, 3))

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish("$N微一凝神，默默运转体内所蓄的寒冰真气，霎时面部竟呈出一层薄霜。\n",
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

  # LPC remove_effect：tell_object(me, "你的寒冰真气运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的寒冰真气运行完毕，将内力收回丹田。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
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
  #                 return notify_fail("你只能用寒冰真气来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("hanbing-zhenqi", 1);
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  #         message_combatd(HIW "$N" HIW "微一凝神，默默运转体内所蓄的寒"
  #                         "冰真气，霎时面部竟呈出一层薄霜。\n" NOR, me);
  #         me->add_temp("apply/attack", skill / 3);
  #         me->add_temp("apply/defense", skill / 3);
  #         me->set_temp("powerup", 1);
  # 
  #         me->start_call_out((:call_other, __FILE__, "remove_effect", me,
  #                            skill / 3:), skill);
  #         if (me->is_fighting()) me->start_busy(1 + random(3));
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("powerup"))
  #         {
  #                 me->add_temp("apply/attack", -amount);
  #                 me->add_temp("apply/defense", -amount);
  #                 me->delete_temp("powerup");
  #                 tell_object(me, "你的寒冰真气运行完毕，将内力收回丹田。\n");
  #         }
  # }
end

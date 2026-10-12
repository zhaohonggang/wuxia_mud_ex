defmodule Kantele.Combat.Skills.Performs.HanbingZhenqi.Freezing do
  @moduledoc """
  exert「freezing」（source hanbing-zhenqi/freezing.c）

  门槛（按 `.c` 顺序）：已学此招 → 未在「寒冰真气」状态 → 目标为自身 →
  寒冰真气>=140 → 先天根骨>=34 → 内力上限>=2200 → 已运功（`powerup`）→
  真气>=1000。
  扣 300 真气；置 `freezing` 标记（持续 寒冰真气 秒）；战斗中忙乱 3。

  差异（TODO(migrate)）：
  - `apply/attack`、`apply/defense` 与 `set_temp("freezing")` 由引擎 buff
    机制承担（真实运行为 `Kantele.Combat.Skills.HanbingZhenqi.Freezing` 的
    `Performs.Simple` spec，见 `skills/hanbing_zhenqi.ex`），本文件为并存的对齐副本；
  - `.c` 的 `target != me` 门槛在 exert 语境下恒真，引擎 spec 未单列该门槛，
    此处仅保留文案以对齐 `.c`；
  - `.c` 的 `me->start_call_out(remove_effect, skill)`（持续 寒冰真气 秒）与
    `tell_object` 到期文案以 `@doc false` 的 `expire_message/0` 保留
    （对齐副本不调度定时器）；
  - `.c` 的 `receive_damage("qi", 0)` 式无文案细节与 `start_busy` 的
    战斗中条件一致保留。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @perform_id "hanbing-zhenqi/freezing"
  @move_name "「寒冰真气」"

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
    with :ok <- check_perform_known(character),
         :ok <- check_not_freezing(character),
         :ok <- check_target(character),
         :ok <- check_skill(character),
         :ok <- check_con(character),
         :ok <- check_max_neili(character),
         :ok <- check_powerup(character),
         :ok <- check_neili(character) do
      :ok
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/hanbing-zhenqi/freezing"))
  #        return notify_fail("你所学的内功中没有这种功能。\n");
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  # LPC: if ((int)me->query_temp("freezing"))
  #        return notify_fail("你现在正在施展" FRE "。\n");
  defp check_not_freezing(character) do
    if Combat.buff_active?(character.meta.combat, "freezing") do
      {:error, "你现在正在施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail(FRE "只能对自己使用。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "#{@move_name}只能对自己使用。\n"
    :ok
  end

  # LPC: skill = me->query_skill("hanbing-zhenqi", 1); if (skill < 140)
  #        return notify_fail("你的寒冰真气不够，难以施展" FRE "。\n");
  defp check_skill(character) do
    if Stats.skill(character.meta.stats, "hanbing-zhenqi") < 140 do
      {:error, "你的寒冰真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("con") < 34)
  #        return notify_fail("你的先天根骨不足，无法施展" FRE "。\n");
  defp check_con(character) do
    if character.meta.stats.con < 34 do
      {:error, "你的先天根骨不足，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 2200)
  #        return notify_fail("你的内力修为不足，难以施展" FRE "。\n");
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 2200 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! me->query_temp("powerup"))
  #        return notify_fail("你现在尚未曾运功，难以施展" FRE "。\n");
  defp check_powerup(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      :ok
    else
      {:error, "你现在尚未曾运功，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 1000)
  #        return notify_fail("你目前的内力不够，难以施展" FRE "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 1000 do
      {:error, "你目前的内力不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -300);
    #      message_combatd(HIW "$N" HIW "一声冷笑，体内寒冰真气迅速疾转数个周"
    #                      "天，将力聚于掌心。\n" NOR, me);
    #      me->set_temp("freezing", 1);
    #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill :), skill);
    #      if (me->is_fighting()) me->start_busy(3);
    skill = Stats.skill(character.meta.stats, "hanbing-zhenqi")

    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 300, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat =
      character.meta.combat
      |> Combat.add_buff(%Buff{key: "freezing", applies: %{}, duration: skill})
      |> start_busy_if_fighting(3)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish("$N一声冷笑，体内寒冰真气迅速疾转数个周天，将力聚于掌心。\n",
      n1: character.name
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp start_busy_if_fighting(combat, rounds) do
    if Combat.fighting?(combat), do: Combat.start_busy(combat, rounds), else: combat
  end

  # LPC remove_effect：tell_object(me, "你的" FRE "运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的#{@move_name}运行完毕，将内力收回丹田。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # inherit F_CLEAN_UP;
  # 
  # #define FRE "「" HIW "寒冰真气" NOR "」"
  # 
  # void remove_effect(object me);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  #         if (userp(me) && ! me->query("can_perform/hanbing-zhenqi/freezing"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if ((int)me->query_temp("freezing"))
  #                 return notify_fail("你现在正在施展" FRE "。\n");
  # 
  #         if (target != me)
  #                 return notify_fail(FRE "只能对自己使用。\n");
  # 
  #         skill = me->query_skill("hanbing-zhenqi", 1);
  # 
  #         if (me->query("con") < 34)
  #                 return notify_fail("你的先天根骨不足，无法施展" FRE "。\n");
  # 
  #         if (skill < 140)
  #                 return notify_fail("你的寒冰真气不够，难以施展" FRE "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2200)
  #                 return notify_fail("你的内力修为不足，难以施展" FRE "。\n");
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你现在尚未曾运功，难以施展" FRE "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你目前的内力不够，难以施展" FRE "。\n");
  # 
  #         me->add("neili", -300);
  # 
  #         message_combatd(HIW "$N" HIW "一声冷笑，体内寒冰真气迅速疾转数个周"
  #                         "天，将力聚于掌心。\n" NOR, me);
  #         me->set_temp("freezing", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill :), skill);
  #         if (me->is_fighting())
  #                 me->start_busy(3);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me)
  # {
  #         if (me->query_temp("freezing"))
  #         {
  #                 me->delete_temp("freezing");
  #                 tell_object(me, "你的" FRE "运行完毕，将内力收回丹田。\n");
  #         }
  # }
end

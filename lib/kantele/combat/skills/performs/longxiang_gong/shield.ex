defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Shield do
  @moduledoc """
  exert「shield / 龙象护体」（source longxiang-gong/exert/shield.c，inherit F_CLEAN_UP）

  自身护体：`layer = min(龙象般若功/30, 13)`；门槛（按 .c 顺序）：仅自身 →
  `layer>=3` → 真气>=500 → 未在运功中。广播后按 skill 给 armor 临时加成
  `skill/2`，扣真气 100，置 `shield` 标记；战斗中忙乱 2。定时移除
  （remove_effect）未做 call_out 自动回收，仅保留其文案。

  差异（TODO(migrate)）：
  - `target != me` 在框架 exert 中恒为自身，`check_target/1` 恒为 :ok，仅保留文案；
  - `.c` 的 `me->query_temp("shield")` 以 `combat.temp[:shield]` 代理。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @cn_digits ~w(零 一 二 三 四 五 六 七 八 九 十)

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    # LPC: skill = me->query_skill("longxiang-gong", 1); layer = skill / 30;
    #      if (layer > 13) layer = 13;
    layer = min(div(Stats.skill(stats, "longxiang-gong"), 30), 13)

    with :ok <- check_target(character),
         :ok <- check_layer(layer),
         :ok <- check_resources(character),
         :ok <- check_state(character) do
      apply_effect(conn, character, layer)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能提升自己的防御力。\n");
  defp check_target(_character) do
    # 框架 exert 的 target 即自身
    _msg = "你只能提升自己的防御力。\n"
    :ok
  end

  # LPC: if (layer < 3) return notify_fail("你龙象般若功修为不够，难以运功。\n");
  defp check_layer(layer) do
    if layer < 3 do
      {:error, "你龙象般若功修为不够，难以运功。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500) return notify_fail("你目前的真气不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你目前的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("shield")) return notify_fail("你已经在运功中了。\n");
  defp check_state(character) do
    if Map.get(character.meta.combat.temp || %{}, :shield) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, layer) do
    # LPC: remove_effect: tell_object(me, "你的龙象般若功运行完毕，将内力收回丹田。\n");
    _remove = "你的龙象般若功运行完毕，将内力收回丹田。\n"
    skill = Stats.skill(character.meta.stats, "longxiang-gong")

    # LPC: message_combatd(HIW "$N" HIW "暗聚龙象般若功第" + chinese_number(layer) +
    #            "层功力，顿时一股白雾蒸腾而起，瞬间笼罩$N" HIW "全身！\n" NOR, me);
    conn =
      Broadcast.publish(
        conn,
        "$N暗聚龙象般若功第" <>
          chinese_number(layer) <> "层功力，顿时一股白雾蒸腾而起，瞬间笼罩$N全身！\n",
        n1: character.name
      )

    # LPC: me->add_temp("apply/armor", skill / 2); me->add("neili", -100);
    #      me->set_temp("shield", 1);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{armor: div(skill, 2)})
    combat = %{combat | temp: Map.put(combat.temp || %{}, :shield, 1)}

    # LPC: if (me->is_fighting()) me->start_busy(2);
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 2), else: combat
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: chinese_number(layer) —— 层数（3..13）。
  defp chinese_number(i) when i < 0, do: "负" <> chinese_number(-i)
  defp chinese_number(i) when i <= 10, do: Enum.at(@cn_digits, i)
  defp chinese_number(i) when i < 20, do: "十" <> Enum.at(@cn_digits, i - 10)

  defp chinese_number(i) when i < 100 do
    if rem(i, 10) == 0 do
      Enum.at(@cn_digits, div(i, 10)) <> "十"
    else
      Enum.at(@cn_digits, div(i, 10)) <> "十" <> Enum.at(@cn_digits, rem(i, 10))
    end
  end

  defp chinese_number(i), do: Integer.to_string(i)

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill, layer;
  # 
  #         skill = me->query_skill("longxiang-gong", 1);
  #         layer = skill / 30;
  # 
  #         if (layer > 13) layer = 13;
  # 
  #         if (target != me)
  #                 return notify_fail("你只能提升自己的防御力。\n");
  # 
  #         if (layer < 3)
  #                 return notify_fail("你龙象般若功修为不够，难以运功。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你目前的真气不够。\n");
  # 
  #         if ((int)me->query_temp("shield"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         message_combatd(HIW "$N" HIW "暗聚龙象般若功第" + chinese_number(layer) +
  #                         "层功力，顿时一股白雾蒸腾而起，瞬间笼罩$N" HIW "全身！\n"
  #                         NOR, me);
  # 
  #         me->add_temp("apply/armor", skill / 2);
  #         me->add("neili", -100);
  #         me->set_temp("shield", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                               me, skill / 2:), skill);
  # 
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("shield"))
  #         {
  #                 me->add_temp("apply/armor", -amount);
  #                 me->delete_temp("shield");
  #                 tell_object(me, "你的龙象般若功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end

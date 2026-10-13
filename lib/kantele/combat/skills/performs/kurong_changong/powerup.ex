defmodule Kantele.Combat.Skills.Performs.KurongChangong.Powerup do
  @moduledoc """
  exert「powerup」（source kurong-changong/powerup.c，inherit F_CLEAN_UP）

  自身加力：消耗 100 内力，按枯荣禅功等级给 attack/defense 临时加成 skill/3，
  置 powerup 临时标记（运功中不可重复施展）；战斗中收招忙乱 1~3。
  起手式文案按等级分四档：>250 亦枯亦荣 / >200 全荣 / >150 全枯 / 其余 半枯半荣。
  定时移除（remove_effect）未做 call_out 自动回收，仅保留收回文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_state(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能用枯荣禅功来提升自己的战斗力。\n");
  defp check_target(_character) do
    # 框架内 exert 的 target 即自身
    _msg = "你只能用枯荣禅功来提升自己的战斗力。\n"
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
  defp check_state(character) do
    if Map.get(character.meta.combat.temp || %{}, :powerup) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: me->receive_damage("qi", 0) 是空操作，略。
    # remove_effect 的收回文案（call_out 未建模，仅保留字面量）：
    _remove_msg = "你的枯荣禅功运行完毕，将内力收回丹田。\n"

    skill = Stats.skill(character.meta.stats, "kurong-changong")
    rng = &:rand.uniform/1

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: add_temp("apply/attack", skill/3) / add_temp("apply/defense", skill/3)
    amount = div(skill, 3)
    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: amount, defense: amount})
    combat = %{combat | temp: Map.put(combat.temp || %{}, :powerup, 1)}
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 1 + Engine.rand(rng, 3)), else: combat
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(Messages.interpolate(powerup_message(skill), [n1: character.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC 起手式四档文案（HIC/HIG/YEL/HIY 颜色宏已剥，相邻字面量合并）：
  #   >250 亦枯亦荣 / >200 全荣 / >150 全枯 / 其余 半枯半荣
  defp powerup_message(skill) do
    cond do
      skill > 250 ->
        "$N运起枯荣禅功，全身皮肤竟变得一半犹如婴儿，另一半却似干皱的树皮。\n"
      skill > 200 ->
        "$N暗自凝神，运起枯荣禅功，全身皮肤竟变得犹如婴儿般光滑亮泽。\n"
      skill > 150 ->
        "$N暗自凝神，运起枯荣禅功，全身皮肤竟变得犹如树皮般干皱苍老。\n"
      true ->
        "$N暗自凝神，运起枯荣禅功，真气顿时游遍全身。\n"
    end
  end
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
  #                 return notify_fail("你只能用枯荣禅功来提升自己的战斗力。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if ((int)me->query_temp("powerup"))
  #                 return notify_fail("你已经在运功中了。\n");
  # 
  #         skill = me->query_skill("kurong-changong", 1);
  #         me->add("neili", -100);
  #         me->receive_damage("qi", 0);
  # 
  #         // 亦枯亦荣
  #         if ((int)me->query_skill("kurong-changong", 1) > 250)
  #             message_combatd(HIG "$N" HIG "运起枯荣禅功，全身皮肤竟变得一半犹"
  #                                 "如婴儿，另一半却似干皱的树皮。\n" NOR, me);
  #         // 全荣
  #         else if ((int)me->query_skill("kurong-changong", 1) > 200)
  #             message_combatd(HIC "$N" HIC "暗自凝神，运起枯荣禅功，全身皮肤竟"
  #                                 "变得犹如婴儿般光滑亮泽。\n" NOR, me);
  #         // 全枯
  #         else if ((int)me->query_skill("kurong-changong", 1) > 150)
  #             message_combatd(YEL "$N" YEL "暗自凝神，运起枯荣禅功，全身皮肤竟"
  #                                 "变得犹如树皮般干皱苍老。\n" NOR, me);
  #         // 半枯半荣
  #         else
  #             message_combatd(HIY "$N" HIY "暗自凝神，运起枯荣禅功，真气顿时游"
  #                                 "遍全身。\n" NOR, me);
  # 
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
  #                 tell_object(me, "你的枯荣禅功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end

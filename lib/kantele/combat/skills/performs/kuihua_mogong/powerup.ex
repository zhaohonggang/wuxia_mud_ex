defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Powerup do
  @moduledoc """
  exert「powerup」（source kuihua-mogong/exert/powerup.c，inherit F_CLEAN_UP）

  自身加力：消耗 100 内力，按 force 等级给 attack/parry/dodge 临时加成。
  已打通任督二脉（breakup）时 attack 2/3、parry/dodge 1/4，
  否则 attack 1/3、parry/dodge 1/5；运功期间战斗中忙乱 3。
  定时移除（remove_effect）未做 call_out 自动回收，仅保留文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
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

  # LPC: if (target != me) return notify_fail("你只能用葵花魔功提升自己的战斗力。\n");
  defp check_target(_character) do
    # 框架内 exert 的 target 即自身
    _msg = "你只能用葵花魔功提升自己的战斗力。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 110) return notify_fail("你的真气不够！");
  defp check_resources(character) do
    if character.meta.vitals.neili < 110 do
      {:error, "你的真气不够！\n"}
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
    _remove = "你的葵花魔功运行完毕，将内力收回丹田。\n"
    skill = Stats.skill(character.meta.stats, "force")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # 打通任督二脉（breakup）时加成为 attack 2/3、parry/dodge 1/4，否则 1/3、1/5
    {atk, par, dod} =
      if SpecialSkills.owned?(character.attributes, "breakup") do
        {div(skill * 2, 3), div(skill, 4), div(skill, 4)}
      else
        {div(skill, 3), div(skill, 5), div(skill, 5)}
      end

    combat = character.meta.combat
    combat = Combat.apply_temp(combat, %{attack: atk, parry: par, dodge: dod})
    combat = %{combat | temp: Map.put(combat.temp || %{}, :powerup, 1)}
    combat = if Combat.fighting?(combat), do: Combat.start_busy(combat, 3), else: combat
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N脸色忽红忽白，邪气大现，眼中精光一亮，渐渐又失去神色。\n",
        [n1: character.name]
      )
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // powerup.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #     int skill;
  # 
  #     if (target != me)
  #         return notify_fail("你只能用葵花魔功提升自己的战斗力。\n");
  # 
  #     if ((int)me->query("neili") < 110)
  #         return notify_fail("你的真气不够！");
  # 
  #     if ((int)me->query_temp("powerup"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     skill = me->query_skill("force");
  # 
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 0);
  # 
  #     message_combatd(HIR "$N" HIR "脸色忽红忽白，邪气大现，眼"
  #                         "中精光一亮，渐渐又失去神色。\n" NOR, me);
  #         //打通任督二脉的效果
  # 
  #         if (me->query("breakup"))
  #         {
  #        me->add_temp("apply/attack", skill * 2 / 3);
  #          me->add_temp("apply/parry", skill / 4);
  #          me->add_temp("apply/dodge", skill / 4);
  #          me->set_temp("powerup", 1);
  #         }
  #         else
  #         {
  #          me->add_temp("apply/attack", skill / 3);
  #          me->add_temp("apply/parry", skill / 5);
  #          me->add_temp("apply/dodge", skill / 5);
  #          me->set_temp("powerup", 1);
  #         }
  #     me->start_call_out( (: call_other, __FILE__, "remove_effect", me, skill :), skill /2);
  # 
  #     if (me->is_fighting()) me->start_busy(3);
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if ((int)me->query_temp("powerup"))
  #         {
  #              if (me->query("breakup"))
  #              {
  #             me->add_temp("apply/attack", - (amount * 2 / 3));
  #             me->add_temp("apply/parry", - (amount / 4));
  #             me->add_temp("apply/dodge", - (amount / 4));
  #              }
  #              else
  #              {
  #              me->add_temp("apply/attack", - (amount / 3));
  #             me->add_temp("apply/parry", - (amount / 5));
  #             me->add_temp("apply/dodge", - (amount / 5));
  #              }
  #          me->delete_temp("powerup");
  #          tell_object(me, "你的葵花魔功运行完毕，将内力收回丹田。\n");
  #         }
  # }
end

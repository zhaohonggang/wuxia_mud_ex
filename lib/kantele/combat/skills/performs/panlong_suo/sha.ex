defmodule Kantele.Combat.Skills.Performs.PanlongSuo.Sha do
  @moduledoc """
  perform「绝命七杀」（source panlong-suo/sha.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"count", "whip"}], "level_gates": [{"force", "220"}, {"panlong-suo", "180"}], "map_gates": [{"whip", "panlong-suo"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的霹雳盘龙索还不到家，难以施展", "你没有激发霹雳盘龙索，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "心底一惊，连忙全神应对，不敢有"
      #                          "丝毫大意。\n" NOR"], "success": ["HIR "突然间$N" HIR "猛的猱身扑上，手中" + weapon->name() +
      #                 HIR "急转，便似不要命般地向$n" HIR "猛攻过去。\n" NOR", "= HIR "$n" HIR "卒不及防，登时手忙脚乱，招架疏"
      #                          "散，慌忙中难以抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define SHA "「" HIR "绝命七杀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #         string msg;
      #         int count;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/panlong-suo/sha"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(SHA "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon")) ||
      #         (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你使用的武器不对，难以施展" SHA "。\n");
      # 
      #     if ((int)me->query_skill("force") < 220)
      #         return notify_fail("你的内功火候不够，难以施展" SHA "。\n");
      # 
      #     if ((int)me->query_skill("panlong-suo", 1) < 180)
      #         return notify_fail("你的霹雳盘龙索还不到家，难以施展" SHA "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "panlong-suo")
      #                 return notify_fail("你没有激发霹雳盘龙索，难以施展" SHA "。\n");
      # 
      #     if ((int)me->query("neili") < 300)
      #         return notify_fail("你的真气不够，难以施展" SHA "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "突然间$N" HIR "猛的猱身扑上，手中" + weapon->name() +
      #               HIR "急转，便似不要命般地向$n" HIR "猛攻过去。\n" NOR;
      # 
      #         if (random(me->query_skill("whip")) > target->query_skill("parry") / 2)
      #         {
      #                 msg += HIR "$n" HIR "卒不及防，登时手忙脚乱，招架疏"
      #                        "散，慌忙中难以抵挡。\n" NOR;
      #                 count = me->query_skill("whip") / 20;
      #         } else
      #         {
      #                 msg += HIC "$n" HIC "心底一惊，连忙全神应对，不敢有"
      #                        "丝毫大意。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #     message_combatd(msg, me, target);
      #     me->add("neili", -180);
      #         me->add_temp("apply/attack", count);
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      #             COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #     me->start_busy(1 + random(6));
      #     return 1;
      # }
end

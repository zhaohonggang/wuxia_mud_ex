defmodule Kantele.Combat.Skills.Performs.LongzhuaGong.Zhua do
  @moduledoc """
  perform「zhua」（source longzhua-gong/zhua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "parry"}, {"skill", "longzhua-gong"}], "level_gates": [], "map_gates": [{"claw", "longzhua-gong"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "135"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「神龙抓」只能在战斗中对对手使用。\n", "你的龙爪功等级不够，不会使用「神龙抓」！\n", "你的真气不够，无法运用「神龙抓」！\n", "你没有激发龙爪功，无法使用「神龙抓」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query_skill("claw")", "dp_formula": "target->query_skill("parry") + target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的招式，连消带打，全然化解了$P"
      #                          CYN "的攻势。\n" NOR"], "other": ["HIY "$N" HIY "大喝一声，飞身扑至$n" HIY "面前，随即伸手抓向"
      #             "$p" HIY "的要害！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              HIR "$p" HIR "见来势凶猛，难以躲避，只好"
      #                                              "勉强化解，谁知$P" HIR "的手好像长了眼睛"
      #                                              "一般，扑哧一下正抓中$p" HIR "的要害，登"
      #                                              "时鲜血飞溅！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-180"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // zhua.c 神龙抓
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me)
      # {
      #     string msg;
      #     object target;
      #     int skill, ap, dp, damage;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("「神龙抓」只能在战斗中对对手使用。\n");
      # 
      #     skill = me->query_skill("longzhua-gong", 1);
      # 
      #     if (skill < 135)
      #         return notify_fail("你的龙爪功等级不够，不会使用「神龙抓」！\n");
      # 
      #     if (me->query("neili") < 200)
      #         return notify_fail("你的真气不够，无法运用「神龙抓」！\n");
      # 
      #     if (me->query_skill_mapped("claw") != "longzhua-gong")
      #         return notify_fail("你没有激发龙爪功，无法使用「神龙抓」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "大喝一声，飞身扑至$n" HIY "面前，随即伸手抓向"
      #           "$p" HIY "的要害！\n" NOR;
      # 
      #     ap = me->query_skill("force") + me->query_skill("claw");
      #     dp = target->query_skill("parry") + target->query_skill("dodge");
      #     if (ap / 2 + random(ap) > dp)
      #     {
      #         me->add("neili", -180);
      #         damage = ap / 3 + random(ap / 3);
      #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                            HIR "$p" HIR "见来势凶猛，难以躲避，只好"
      #                                            "勉强化解，谁知$P" HIR "的手好像长了眼睛"
      #                                            "一般，扑哧一下正抓中$p" HIR "的要害，登"
      #                                            "时鲜血飞溅！\n" NOR);
      #         me->start_busy(2);
      #     } else
      #     {
      #         msg += CYN "可是$p" CYN "的看破了$P" CYN
      #                        "的招式，连消带打，全然化解了$P"
      #                        CYN "的攻势。\n" NOR;
      #         me->add("neili",-60);
      #         me->start_busy(3);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end

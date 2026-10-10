defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Jue do
  @moduledoc """
  perform「jue」（source bluesea-force/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "bluesea-force"}, {"dp", "parry"}], "level_gates": [{"bluesea-force", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["绝仙决只能对战斗中的对手使用。\n", "你的南海玄功还不够娴熟，不能使用绝仙决！\n", "你的内力不够，不能使用绝仙决！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("bluesea-force", 1) * 3 / 2 + me->query("con") * 20 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("parry") + target->query("dex") * 20 +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIC", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "哈哈大笑，一掌挥出，变化出满天掌影，封住了$n"
      #                 HIC "所有的退路！\n" NOR", "= HIG "然而$n" HIG "看破了$N" HIG
      #                          "的掌势，不慌不忙的躲过了这一击！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "竭力腾挪躲闪，却听“啪”的"
      #                                              "一声被$P" HIR "结结实实的打在了胸前，登"
      #                                      "时吐血不止！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-50"}, {"neili", "-75"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}, {"neili", "-75"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // jue.c 绝仙决
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #     int ap, dp;
      #         int damage;
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("绝仙决只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_skill("bluesea-force", 1) < 120)
      #         return notify_fail("你的南海玄功还不够娴熟，不能使用绝仙决！\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的内力不够，不能使用绝仙决！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "哈哈大笑，一掌挥出，变化出满天掌影，封住了$n"
      #               HIC "所有的退路！\n" NOR;
      # 
      #     ap = me->query_skill("bluesea-force", 1) * 3 / 2 + me->query("con") * 20 +
      #              me->query_skill("martial-cognize", 1);
      #     dp = target->query_skill("parry") + target->query("dex") * 20 +
      #              target->query_skill("martial-cognize", 1);
      # 
      #         me->start_busy(2);
      #         me->add("neili", -50);
      #         if (ap / 2 + random(ap) < dp)
      #         {
      #         msg += HIG "然而$n" HIG "看破了$N" HIG
      #                        "的掌势，不慌不忙的躲过了这一击！\n" NOR;
      #         } else
      #     {
      #         me->add("neili",-75);
      #                 damage = ap / 2 + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                            HIR "$n" HIR "竭力腾挪躲闪，却听“啪”的"
      #                                            "一声被$P" HIR "结结实实的打在了胸前，登"
      #                                    "时吐血不止！\n" NOR);
      #     }
      # 
      #     message_combatd(msg, me, target);
      #     return 1;
      # }
end

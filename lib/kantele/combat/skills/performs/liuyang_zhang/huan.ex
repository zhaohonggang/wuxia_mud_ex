defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Huan do
  @moduledoc """
  perform「寰阳式」（source liuyang-zhang/huan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"damage", "strike"}, {"dp", "force"}], "level_gates": [{"force", "200"}, {"liuyang-zhang", "130"}], "map_gates": [{"strike", "liuyang-zhang"}], "prepared_gates": [{"strike", "liuyang-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不够，难以施展", "你的天山六阳掌不够娴熟，难以施展", "你没有激发天山六阳掌，难以施展", "你没有准备使用天山六阳掌，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "可是$p" HIC "强运内力，硬生生的挡住$P"
      #                          HIC "这一掌，没有受到任何伤害。\n"NOR"], "success": ["HIR "$N" HIR "双掌一振，施出天山六阳掌「寰阳式」，幻出"
      #                 "满天掌影，团团罩住$n" HIR "。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                              HIR "$n" HIR "见躲闪不得，只能硬挡下一"
      #                                              "招，顿时被$P" HIR "震得连退数步，吐血"
      #                                              "不止！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("strike") + ap - dp"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define HUAN "「" HIR "寰阳式" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //    object weapon;
      #     int damage;
      #     string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/huan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(HUAN "只能空手施展。\n");
      # 
      #         if (me->query_skill("force") < 200)
      #                 return notify_fail("你的内功火候不够，难以施展" HUAN "。\n");
      # 
      #         if ((int)me->query_skill("liuyang-zhang", 1) < 130)
      #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" HUAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
      #                 return notify_fail("你没有激发天山六阳掌，难以施展" HUAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
      #                 return notify_fail("你没有准备使用天山六阳掌，难以施展" HUAN "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你的真气不够，难以施展" HUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIR "$N" HIR "双掌一振，施出天山六阳掌「寰阳式」，幻出"
      #               "满天掌影，团团罩住$n" HIR "。\n" NOR;
      # 
      #     me->add("neili", -50);
      #         ap = me->query_skill("force");
      #         dp = target->query_skill("force");
      #         if (ap / 2 + random(ap) > dp)
      #     {
      #         damage = me->query_skill("strike") + ap - dp;
      #                 damage += random(damage * 2 / 5);
      #         me->add("neili", -100);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                            HIR "$n" HIR "见躲闪不得，只能硬挡下一"
      #                                            "招，顿时被$P" HIR "震得连退数步，吐血"
      #                                            "不止！\n" NOR);
      #         me->start_busy(3);
      #     } else
      #     {
      #         msg += HIC "可是$p" HIC "强运内力，硬生生的挡住$P"
      #                        HIC "这一掌，没有受到任何伤害。\n"NOR;
      #         me->start_busy(3);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end

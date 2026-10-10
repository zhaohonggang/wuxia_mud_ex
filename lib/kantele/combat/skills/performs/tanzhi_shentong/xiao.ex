defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Xiao do
  @moduledoc """
  perform「啸沧海」（source tanzhi-shentong/xiao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "force"}], "level_gates": [{"jingluo-xue", "200"}, {"tanzhi-shentong", "200"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "0"}, {"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的弹指神通不够娴熟，难以施展", "你对经络学的了解不够，难以施展", "你没有激发弹指神通，难以施展", "你没有准备弹指神通，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "突然间$N" HIG "指锋一转，力聚指尖“嗤”的弹出一道紫芒，直袭$n"
      #                 HIG "气海大穴。\n" NOR", "= CYN "可是$p" CYN "防守严密，紧守门户，顿时令$P"
      #                          CYN "的攻势化为乌有。\n" NOR"], "success": ["= HIR "$n" HIR "只觉$N" HIR "指风袭体，随即上体一"
      #                          "阵冰凉，顿感真气涣散几欲晕厥。\n" NOR"]}, "damage_formula": %{"formula": "ap"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage * 4 / 3", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 3", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-damage * 3"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define XIAO "「" HIG "啸沧海" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int ap, dp, damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/xiao"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XIAO "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(XIAO "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("tanzhi-shentong", 1) < 200)
      #                 return notify_fail("你的弹指神通不够娴熟，难以施展" XIAO "。\n");
      # 
      #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
      #                 return notify_fail("你对经络学的了解不够，难以施展" XIAO "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有激发弹指神通，难以施展" XIAO "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
      #                 return notify_fail("你没有准备弹指神通，难以施展" XIAO "。\n");
      # 
      #         if (me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不足，难以施展" XIAO "。\n");
      # 
      #         if (me->query("neili") < 800)
      #                 return notify_fail("你现在的真气不够，难以施展" XIAO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIG "突然间$N" HIG "指锋一转，力聚指尖“嗤”的弹出一道紫芒，直袭$n"
      #               HIG "气海大穴。\n" NOR;
      # 
      #         ap = me->query_skill("finger");
      #         dp = target->query_skill("force");
      # 
      #         damage = ap;
      #         damage += random(damage);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 target->receive_damage("jing", damage * 4 / 3, me);
      #                 target->receive_wound("jing", damage / 3, me);
      #         target->add("neili", -damage * 3);
      # 
      #             if (target->query("neili") < 0)
      #                         target->set("neili", 0);
      # 
      #                 msg += HIR "$n" HIR "只觉$N" HIR "指风袭体，随即上体一"
      #                        "阵冰凉，顿感真气涣散几欲晕厥。\n" NOR;
      #                 me->start_busy(3);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "防守严密，紧守门户，顿时令$P"
      #                        CYN "的攻势化为乌有。\n" NOR;
      #                 me->start_busy(4);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

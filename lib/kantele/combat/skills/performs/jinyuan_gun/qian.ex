defmodule Kantele.Combat.Skills.Performs.JinyuanGun.Qian do
  @moduledoc """
  perform「乾坤一击」（source jinyuan-gun/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "club"}, {"dp", "dodge"}], "level_gates": [{"force", "180"}, {"jinyuan-gun", "120"}], "map_gates": [{"club", "jinyuan-gun"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的金猿棍法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发金猿棍法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("club")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "大步上前，怒吼一声，手中" + weapon->name() +
      #                 HIY "急速舞动，霎时间飞沙走石，罡气激荡。\n便在狂沙飓风中"
      #                 "，$N" HIY "忽然高高跃起，迎头一棒朝$n" HIY "劈落！\n" NOR", "= CYN "$n" CYN "不敢有丝毫大意，急忙纵身后跃，躲"
      #                          "开这足以断金裂石的一击。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #                                              HIR "$n" HIR "浑身被劲风笼罩，登感窒息"
      #                                              "，“哇”的吐出一口鲜血，仰面便倒！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap * 2 / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # #define QIAN "「" HIY "乾坤一击" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/jinyuan-gun/qian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "club")
      #                 return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill("force") < 180)
      #                 return notify_fail("你的内功的修为不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill("jinyuan-gun", 1) < 120)
      #                 return notify_fail("你的金猿棍法修为不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，难以施展" QIAN "。\n");
      # 
      #         if (me->query_skill_mapped("club") != "jinyuan-gun")
      #                 return notify_fail("你没有激发金猿棍法，难以施展" QIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "大步上前，怒吼一声，手中" + weapon->name() +
      #               HIY "急速舞动，霎时间飞沙走石，罡气激荡。\n便在狂沙飓风中"
      #               "，$N" HIY "忽然高高跃起，迎头一棒朝$n" HIY "劈落！\n" NOR;
      # 
      #         ap = me->query_skill("club");
      #         dp = target->query_skill("dodge");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 2 + random(ap * 2 / 3);
      #                 me->add("neili", -150);
      #                 me->start_busy(2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #                                            HIR "$n" HIR "浑身被劲风笼罩，登感窒息"
      #                                            "，“哇”的吐出一口鲜血，仰面便倒！\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -100);
      #                 me->start_busy(3);
      #                 msg += CYN "$n" CYN "不敢有丝毫大意，急忙纵身后跃，躲"
      #                        "开这足以断金裂石的一击。\n"NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

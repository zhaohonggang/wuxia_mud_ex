defmodule Kantele.Combat.Skills.Performs.ZigaiJian.Hui do
  @moduledoc """
  perform「紫盖回翔」（source zigai-jian/hui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "zigai-jian"}, {"dp", "dodge"}], "level_gates": [{"dodge", "120"}, {"force", "150"}, {"zigai-jian", "120"}], "map_gates": [{"sword", "zigai-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你紫盖剑法不够娴熟，难以施展", "你没有激发紫盖剑法，难以施展", "你的内功火候不够，难以施展", "你的轻功火候不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("zigai-jian", 1)", "dp_formula": "target->query_skill("dodge", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N" HIY "撤剑转身向后一纵，似欲逃走，$n" HIY "乘机挺"
      #                 "剑上前，" HIY "眼见$n" HIY "即\n将得手，不料$N" HIY "凌空"
      #                 "回身反刺，" + wn + HIY "直指$n" HIY "。" NOR", "CYN "然而$n" CYN "眼见" + wn + CYN "已至，但$n"
      #                         CYN "身法迅速无比，提气向后一纵，$N" CYN "扑了"
      #                         "个空。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
      #                                             HIR "$n" HIR "心中一惊，虽知中计，但"
      #                                             + wn + HIR "突如其来迅捷无比，已然闪"
      #                                             "避不及。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define HUI "「" HIC "紫盖回翔" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg, wn;
      #         object weapon;
      #         int ap, dp;
      # 
      #         me = this_player();
      # 
      #         if (userp(me) && ! me->query("can_perform/zigai-jian/hui"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(HUI "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query_skill("zigai-jian", 1) < 120)
      #                 return notify_fail("你紫盖剑法不够娴熟，难以施展" HUI "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "zigai-jian")
      #                 return notify_fail("你没有激发紫盖剑法，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 150 )
      #                 return notify_fail("你的内功火候不够，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query_skill("dodge") < 120)
      #                 return notify_fail("你的轻功火候不够，难以施展" HUI "。\n");
      # 
      #         if ((int)me->query("neili") < 150)
      #                 return notify_fail("你现在的真气不够，难以施展" HUI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wn = weapon->name();
      # 
      #         msg = HIY "\n$N" HIY "撤剑转身向后一纵，似欲逃走，$n" HIY "乘机挺"
      #               "剑上前，" HIY "眼见$n" HIY "即\n将得手，不料$N" HIY "凌空"
      #               "回身反刺，" + wn + HIY "直指$n" HIY "。" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         ap = me->query_skill("zigai-jian", 1);
      #         dp = target->query_skill("dodge", 1);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #              damage = ap + random(ap / 2);
      # 
      #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
      #                                           HIR "$n" HIR "心中一惊，虽知中计，但"
      #                                           + wn + HIR "突如其来迅捷无比，已然闪"
      #                                           "避不及。\n" NOR);
      # 
      #              me->start_busy(2);
      #              me->add("neili", -100);
      #         } else
      #         {
      #              msg = CYN "然而$n" CYN "眼见" + wn + CYN "已至，但$n"
      #                       CYN "身法迅速无比，提气向后一纵，$N" CYN "扑了"
      #                       "个空。\n" NOR;
      # 
      #              me->start_busy(3);
      #              me->add("neili", -50);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

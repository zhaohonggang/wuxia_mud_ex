defmodule Kantele.Combat.Skills.Performs.XueshanJian.Feng do
  @moduledoc """
  perform「剑气封喉」（source xueshan-jian/feng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"force", "240"}, {"xueshan-jian", "160"}], "map_gates": [{"sword", "xueshan-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的雪山剑法修为不够，难以施展", "你的真气不够，难以施展", "你没有激发雪山剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force")", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只听$N" HIW "一声清啸，手中" + weapon->name() +
      #                 HIW "龙吟不止，迸出万道光华，疾闪而过，无数劲风席卷"
      #                 "$n" HIW "而去！\n" NOR", "= CYN "可是$n" CYN "看破" CYN "$N" CYN
      #                          "的招数，飞身跃开丈许，终于将这阴寒剑"
      #                          "气驱于无形。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 90,
      #                                              HIR "$n" HIR "只感寒风袭体，全身一阵冰"
      #                                              "凉，已被$N" HIR "剑气所伤。顿时喉咙一"
      #                                              "甜，喷出一大口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
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
      # // feng.c
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define FENG "「" HIW "剑气封喉" NOR "」"
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
      #         if (userp(me) && ! me->query("can_perform/xueshan-jian/feng"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(FENG "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" FENG "。\n");
      # 
      #         if (me->query_skill("force") < 240)
      #                 return notify_fail("你的内功的修为不够，难以施展" FENG "。\n");
      # 
      #         if (me->query_skill("xueshan-jian", 1) < 160)
      #                 return notify_fail("你的雪山剑法修为不够，难以施展" FENG "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，难以施展" FENG "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "xueshan-jian")
      #                 return notify_fail("你没有激发雪山剑法，难以施展" FENG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "只听$N" HIW "一声清啸，手中" + weapon->name() +
      #               HIW "龙吟不止，迸出万道光华，疾闪而过，无数劲风席卷"
      #               "$n" HIW "而去！\n" NOR;
      # 
      #         ap = me->query_skill("sword") + me->query_skill("force");
      #         dp = target->query_skill("dodge") + target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 3 + random(ap / 3);
      #                 me->add("neili", -100);
      #                 me->start_busy(2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 90,
      #                                            HIR "$n" HIR "只感寒风袭体，全身一阵冰"
      #                                            "凉，已被$N" HIR "剑气所伤。顿时喉咙一"
      #                                            "甜，喷出一大口鲜血。\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -50);
      #                 me->start_busy(3);
      #                 msg += CYN "可是$n" CYN "看破" CYN "$N" CYN
      #                        "的招数，飞身跃开丈许，终于将这阴寒剑"
      #                        "气驱于无形。\n"NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.YuxiaoJian.Tian do
  @moduledoc """
  perform「天外清音」（source yuxiao-jian/tian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"qi_wound", "sword"}, {"skill", "yuxiao-jian"}], "level_gates": [{"bibo-shengong", "120"}], "map_gates": [{"sword", "yuxiao-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "1000"}], "var_gates": [{"dp", "1"}, {"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你没有激发玉箫剑法，难以施展", "你玉箫剑法等级不够，难以施展", "你碧波神功修为不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "1"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "一声清啸，手中" + weapon->name() +
      #                 HIC "剑发琴音，闪动不止，剑影如夜幕般扑向$n" HIC "。\n" NOR", "= CYN "可是$n" CYN "宁心静气，随手挥洒，将$N"
      #                          CYN "的招数撇在一边。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, qi_wound, 66,
      #                                              HIR "$n" HIR "顿时觉得眼前金光乱闪动，双耳嗡嗡"
      #                                              "内鸣，全身便如针扎一般！\n" NOR)"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define TIAN "「" HIC "天外清音" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me)
      # {
      #         string msg;
      #         object weapon, target;
      #         int skill, ap, dp/*, neili_wound*/, qi_wound;
      # 
      #         if (userp(me) && ! me->query("can_perform/yuxiao-jian/tian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(TIAN "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" TIAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "yuxiao-jian")
      #                 return notify_fail("你没有激发玉箫剑法，难以施展" TIAN "。\n");
      # 
      #         skill = me->query_skill("yuxiao-jian", 1);
      # 
      #         if (skill < 120)
      #                 return notify_fail("你玉箫剑法等级不够，难以施展" TIAN "。\n");
      # 
      #         if ((int)me->query_skill("bibo-shengong", 1) < 120)
      #                 return notify_fail("你碧波神功修为不够，难以施展" TIAN "。\n");
      # 
      #         if (me->query("neili") < 1000)
      #                 return notify_fail("你现在的真气不足，难以施展" TIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "一声清啸，手中" + weapon->name() +
      #               HIC "剑发琴音，闪动不止，剑影如夜幕般扑向$n" HIC "。\n" NOR;
      # 
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("force");
      # 
      #         if (dp < 1) dp = 1;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -120);
      #                 qi_wound = (int)me->query_skill("sword") +
      #                            (int)me->query_skill("bibo-shengong", 1);
      #                 qi_wound = qi_wound / 2 + random(qi_wound / 2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, qi_wound, 66,
      #                                            HIR "$n" HIR "顿时觉得眼前金光乱闪动，双耳嗡嗡"
      #                                            "内鸣，全身便如针扎一般！\n" NOR);
      #                 me->start_busy(1 + random(3));
      #         } else
      #         {
      #                 me->add("neili", -50);
      #                 msg += CYN "可是$n" CYN "宁心静气，随手挥洒，将$N"
      #                        CYN "的招数撇在一边。\n"NOR;
      #                 me->start_busy(2);
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.ShiguBifa.Feng do
  @moduledoc """
  perform「神笔封穴」（source shigu-bifa/feng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "dagger"}, {"dp", "parry"}, {"skill", "shigu-bifa"}], "level_gates": [{"force", "150"}], "map_gates": [{"dagger", "shigu-bifa"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": [{"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的石鼓打穴笔法修为有限，难以施展", "你现在的真气不足，难以施展", "你没有激发石鼓打穴笔法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("dagger")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的招式，巧妙的一一拆解，没露半点"
      #                          "破绽！\n" NOR"], "success": ["HIR "$N" HIR "飞身一跃而起，贴至$n" HIR "跟前，手中" +
      #                 weapon->name() + HIR "大起大落，气势恢弘，幻出一道闪电"
      #                 "直射$n" HIR "要穴！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "$p" HIR "微微一楞，只觉胸口一麻，"
      #                                              "已被$N" HIR "点中要穴，整个上半身顿时"
      #                                              "瘫软无力，缓缓瘫倒。\n" NOR)"]}, "damage_formula": %{"formula": "100 + ap / 5 + random(ap / 5)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "dagger"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 3 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 25 + 2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - if (ap / 3 + random(ap) > dp && ! target->is_busy())
      #   - target->start_busy(ap / 25 + 2);
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
      # #define FENG "「" HIR "神笔封穴" NOR "」"
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me)
      # {
      #         string msg;
      #         object weapon, target;
      #         int skill, ap, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/shigu-bifa/feng"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail(FENG "只能对战斗中的对手使用。\n");
      # 
      #         weapon = me->query_temp("weapon");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "dagger")
      #                 return notify_fail("你所使用的武器不对，难以施展" FENG "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         skill = me->query_skill("shigu-bifa", 1);
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功的修为不够，难以施展" FENG "。\n");
      # 
      #         if (skill < 100)
      #                 return notify_fail("你的石鼓打穴笔法修为有限，难以施展" FENG "。\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你现在的真气不足，难以施展" FENG "。\n");
      # 
      #         if (me->query_skill_mapped("dagger") != "shigu-bifa")
      #                 return notify_fail("你没有激发石鼓打穴笔法，难以施展" FENG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "飞身一跃而起，贴至$n" HIR "跟前，手中" +
      #               weapon->name() + HIR "大起大落，气势恢弘，幻出一道闪电"
      #               "直射$n" HIR "要穴！\n" NOR;
      #  
      #         ap = me->query_skill("dagger");
      #         dp = target->query_skill("parry");
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -200);
      #                 damage = 100 + ap / 5 + random(ap / 5);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            HIR "$p" HIR "微微一楞，只觉胸口一麻，"
      #                                            "已被$N" HIR "点中要穴，整个上半身顿时"
      #                                            "瘫软无力，缓缓瘫倒。\n" NOR);
      #                 me->start_busy(1);
      #                 if (ap / 3 + random(ap) > dp && ! target->is_busy())
      #                         target->start_busy(ap / 25 + 2);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
      #                        "的招式，巧妙的一一拆解，没露半点"
      #                        "破绽！\n" NOR;
      #                 me->add("neili", -50);
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

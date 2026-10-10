defmodule Kantele.Combat.Skills.Performs.JingangZhi.San do
  @moduledoc """
  perform「一指点三脉」（source jingang-zhi/san.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"damage", "finger"}, {"dp", "parry"}, {"lvl", "jingang-zhi"}], "level_gates": [{"force", "300"}, {"jingang-zhi", "200"}, {"jingluo-xue", "200"}], "map_gates": [{"finger", "jingang-zhi"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [{"finger", "jingang-zhi"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你大力金刚指不够娴熟，难以施展", "你现在没有激发少林内功为内功，难以施展", "你对经络学了解不够，难以施展", "你没有激发大力金刚指，难以施展", "你没有准备大力金刚指，难以施展", "你的内功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "镇定自如，全力化解了$P"
      #                          CYN "这精妙的一指。\n" NOR"], "other": ["HIW "突然间""], "success": ["= "$N" HIW "凝气于指，「" HIR "一指点三脉" HIW "」点出，顿时一股"
      #                  "纯阳的内力直袭$n" HIW "胸口！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                                              HIR "结果$n" HIR "被$N" HIR "一指点中"
      #                                              HIY + xue_name[random(sizeof(xue_name))] +
      #                                              HIR "，全身真气逆流而上，登时呕出一大"
      #                                              "口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("finger") + (int)me->query_skill("force") + (int)me->query_skill("jinluo-xue",1)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-800"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-800"}], "affect_by": [], "apply_adds": [], "busy_lines": ["target->start_busy(lvl/30);", "me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - target->start_busy(lvl/30);
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define DIE "「" HIR "一指点三脉" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string *xue_name = ({
      # "劳宫穴", "膻中穴", "曲池穴", "关元穴", "曲骨穴", "中极穴",
      # "承浆穴", "天突穴", "百会穴", "幽门穴", "章门穴", "大横穴",
      # "紫宫穴", "冷渊穴", "天井穴", "极泉穴", "清灵穴", "至阳穴", });
      # 
      # int perform(object me, object target)
      # {
      #         int damage, lvl;
      #         string msg;
      #         // object weapon;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/jingang-zhi/san"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      # 
      #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(DIE "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("jingang-zhi", 1) < 200)
      #                 return notify_fail("你大力金刚指不够娴熟，难以施展" DIE "。\n");
      # 
      #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
      #                 return notify_fail("你现在没有激发少林内功为内功，难以施展" DIE "。\n");
      #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
      #                 return notify_fail("你对经络学了解不够，难以施展" DIE "。\n");
      # 
      #         if (me->query_skill_mapped("finger") != "jingang-zhi")
      #                 return notify_fail("你没有激发大力金刚指，难以施展" DIE "。\n");
      # 
      #         if (me->query_skill_prepared("finger") != "jingang-zhi")
      #                 return notify_fail("你没有准备大力金刚指，难以施展" DIE "。\n");
      # 
      #         if ((int)me->query_skill("force") < 300)
      #                 return notify_fail("你的内功火候不够，难以施展" DIE "。\n");
      # 
      #         if (me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为不足，难以施展" DIE "。\n");
      # 
      #         if ((int)me->query("neili") < 1000)
      #                 return notify_fail("你现在的真气不够，难以施展" DIE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         damage = (int)me->query_skill("finger") + (int)me->query_skill("force") + (int)me->query_skill("jinluo-xue",1);
      #         damage += random(damage);
      #         lvl = (int)me->query_skill("jingang-zhi", 1);
      #         ap = me->query_skill("finger");
      #         dp = target->query_skill("parry");
      # 
      #         msg = HIW "突然间";
      # 
      #         msg += "$N" HIW "凝气于指，「" HIR "一指点三脉" HIW "」点出，顿时一股"
      #                "纯阳的内力直袭$n" HIW "胸口！\n" NOR;
      #         if (ap * 2 / 3 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                                            HIR "结果$n" HIR "被$N" HIR "一指点中"
      #                                            HIY + xue_name[random(sizeof(xue_name))] +
      #                                            HIR "，全身真气逆流而上，登时呕出一大"
      #                                            "口鲜血。\n" NOR);
      # 
      #                 target->start_busy(lvl/30);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "镇定自如，全力化解了$P"
      #                        CYN "这精妙的一指。\n" NOR;
      #         }
      # 
      # 
      #         me->start_busy(3 + random(3));
      #         me->add("neili", -800);
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.ChongtianZhang.Zhan do
  @moduledoc """
  perform「翅展九州」（source chongtian-zhang/zhan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"damage", "strike"}, {"dp", "force"}], "level_gates": [{"chongtian-zhang", "120"}, {"force", "150"}], "map_gates": [{"strike", "chongtian-zhang"}], "prepared_gates": [{"strike", "chongtian-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不够，难以施展", "你的白鹤冲天掌不够娴熟，难以施展", "你没有激发白鹤冲天掌，难以施展", "你没有准备白鹤冲天掌，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "双臂舒张，掌缘微微颤动，身形一展，已移至$n"
      #                 HIW "跟前，双掌交叉奋力劈下，正是\n白鹤冲天掌「翅展九州」"
      #                 "绝技，空气中顿时爆响出一阵尖锐的破空声。\n" NOR", "= CYN "可是$p" CYN "奋力招架，终于将$P"
      #                          CYN "这双掌架开，没有受到任何伤害。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$n" HIR "躲闪不得，只能硬挡下双掌"
      #                                              "，顿时被$P" HIR "双掌砍中双肩两侧，吐"
      #                                              "血不止！\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("strike") * 3 / 5"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define ZHAN "「" HIW "翅展九州" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/chongtian-zhang/zhan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(ZHAN "只能空手施展。\n");
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功火候不够，难以施展" ZHAN "。\n");
      # 
      #         if ((int)me->query_skill("chongtian-zhang", 1) < 120)
      #                 return notify_fail("你的白鹤冲天掌不够娴熟，难以施展" ZHAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "chongtian-zhang")
      #                 return notify_fail("你没有激发白鹤冲天掌，难以施展" ZHAN "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "chongtian-zhang")
      #                 return notify_fail("你没有准备白鹤冲天掌，难以施展" ZHAN "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你的真气不够，难以施展" ZHAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "双臂舒张，掌缘微微颤动，身形一展，已移至$n"
      #               HIW "跟前，双掌交叉奋力劈下，正是\n白鹤冲天掌「翅展九州」"
      #               "绝技，空气中顿时爆响出一阵尖锐的破空声。\n" NOR;
      # 
      #         me->add("neili", -50);
      #         ap = me->query_skill("strike");
      #         dp = target->query_skill("force");
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = me->query_skill("strike") * 3 / 5;
      #                 damage += random(damage / 3);
      #                 me->add("neili", -100);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                            HIR "$n" HIR "躲闪不得，只能硬挡下双掌"
      #                                            "，顿时被$P" HIR "双掌砍中双肩两侧，吐"
      #                                            "血不止！\n" NOR);
      #                 me->start_busy(3);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "奋力招架，终于将$P"
      #                        CYN "这双掌架开，没有受到任何伤害。\n"NOR;
      #                 me->start_busy(4);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.JindingZhang.Bashi do
  @moduledoc """
  perform「八式合一」（source jinding-zhang/bashi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "linji-zhuang"}], "level_gates": [{"force", "100"}, {"jinding-zhang", "100"}], "map_gates": [{"strike", "jinding-zhang"}], "prepared_gates": [{"strike", "jinding-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力还不够，难以施展", "你的内功的修为不够，难以施展", "你的金顶绵掌的修习不够，难以施展", "你没有激发金顶绵掌，难以施展", "你现在没有准备使用金顶绵掌，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "深深吸了一口气，提起全身的功力于"
      #                 "双掌猛力拍出，只听得骨骼一阵爆响！\n" NOR", "= CYN "可是$p" CYN "猛地向后一跃，跳出了$P"
      #                          CYN "的攻击范围。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "只见漫天掌影飘忽不定的罩向$n" HIR
      #                                              "全身各个部位，$n" HIR "顿时接连中了数"
      #                                              "掌！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("linji-zhuang", 1)"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define BASHI "「" HIY "八式合一" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // object weapon;
      #         int damage;
      #         string msg;
      #         // int count,d_count,qi, maxqi, skill;
      # 
      #         if (userp(me) && ! me->query("can_perform/jinding-zhang/bashi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(BASHI "只能在战斗中对对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(BASHI "只能空手施展。\n");
      # 
      #         if ((int)me->query("neili") < 200)
      #                 return notify_fail("你的内力还不够，难以施展" BASHI "。\n");
      # 
      #         if ((int)me->query_skill("force") < 100)
      #                 return notify_fail("你的内功的修为不够，难以施展" BASHI "。\n");
      # 
      #         if ((int)me->query_skill("jinding-zhang", 1) < 100)
      #                 return notify_fail("你的金顶绵掌的修习不够，难以施展" BASHI "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "jinding-zhang")
      #                 return notify_fail("你没有激发金顶绵掌，难以施展" BASHI "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "jinding-zhang")
      #                 return notify_fail("你现在没有准备使用金顶绵掌，难以施展" BASHI "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "深深吸了一口气，提起全身的功力于"
      #               "双掌猛力拍出，只听得骨骼一阵爆响！\n" NOR;
      #         if (random(me->query_skill("strike")) > (int)target->query_skill("force") / 2)
      #         {
      #                 damage  = (int)me->query_skill("linji-zhuang", 1);
      #                 damage += (int)me->query_skill("jinding-zhang", 1);
      #                 damage /= 3;
      #                 damage += random(damage);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                            HIR "只见漫天掌影飘忽不定的罩向$n" HIR
      #                                            "全身各个部位，$n" HIR "顿时接连中了数"
      #                                            "掌！\n" NOR);
      #                 me->add("neili", -100);
      #                 me->start_busy(2);
      #          } else
      #          {
      #                 msg += CYN "可是$p" CYN "猛地向后一跃，跳出了$P"
      #                        CYN "的攻击范围。\n" NOR;
      #                 me->start_busy(3);
      #          }
      #          message_combatd(msg, me, target);
      #          return 1;
      # }
end

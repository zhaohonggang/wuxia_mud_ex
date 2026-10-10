defmodule Kantele.Combat.Skills.Performs.TaijiQuan.Zhen do
  @moduledoc """
  perform「震字诀」（source taiji-quan/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "force"}, {"skill", "taiji-quan"}], "level_gates": [], "map_gates": [{"unarmed", "taiji-quan"}], "prepared_gates": [{"unarmed", "taiji-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的太极拳等级不够，难以施展", "你的真气不够，难以施展", "你没有激发太极拳，难以施展", "你现在没有准备使用太极拳，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "使出太极拳「震」字诀，左手高，右手低，陡然"
      #                 "回圈，企图以内力震伤$n" HIW "。\n" NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，并没有上当。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                              HIR "只见$N" HIR "这一拳变化无方，气劲"
      #                                              "封了$n" HIR "所有的退路，一拳正好命中"
      #                                              "。\n:内伤@?")"]}, "damage_formula": %{"formula": "(int)me->query_skill("force", 1)"}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(random(3));
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
      # #define ZHEN "「" HIW "震字诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int skill/*, ap, dp*/, damage;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/taiji-quan/zhen"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(ZHEN "只能空手施展。\n");
      # 
      #         skill = me->query_skill("taiji-quan", 1);
      # 
      #         if (skill < 150)
      #                 return notify_fail("你的太极拳等级不够，难以施展" ZHEN "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，难以施展" ZHEN "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "taiji-quan")
      #                 return notify_fail("你没有激发太极拳，难以施展" ZHEN "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "taiji-quan")
      #                 return notify_fail("你现在没有准备使用太极拳，无法使用" ZHEN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "$N" HIW "使出太极拳「震」字诀，左手高，右手低，陡然"
      #               "回圈，企图以内力震伤$n" HIW "。\n" NOR;
      #     me->add("neili", -50);
      # 
      #     if (random(me->query_skill("force")) > target->query_skill("force") / 2)
      #     {
      #         me->start_busy(3);
      #         target->start_busy(random(3));
      # 
      #         damage = (int)me->query_skill("force", 1);
      #                 damage = damage / 2 + random(damage / 2);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                            HIR "只见$N" HIR "这一拳变化无方，气劲"
      #                                            "封了$n" HIR "所有的退路，一拳正好命中"
      #                                            "。\n:内伤@?");
      #     } else
      #     {
      #         me->start_busy(3);
      #         msg += CYN "可是$p" CYN "看破了$P"
      #                        CYN "的企图，并没有上当。\n" NOR;
      #     }
      #     message_combatd(msg, me, target);
      #     return 1;
      # }
end

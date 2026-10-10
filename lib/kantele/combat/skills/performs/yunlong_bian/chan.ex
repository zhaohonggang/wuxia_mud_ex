defmodule Kantele.Combat.Skills.Performs.YunlongBian.Chan do
  @moduledoc """
  perform「缠字诀」（source yunlong-bian/chan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"yunlong-bian", "50"}], "map_gates": [{"whip", "yunlong-bian"}], "prepared_gates": [], "resource_gates": [{"neili", "50"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你云龙鞭法火候太浅，难以施展", "你没有激发云龙鞭法，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIW", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "使出云龙鞭法「缠」字诀，连挥" + weapon->name() +
      #                 WHT"企图把$n"  WHT "的全身缠住。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，并没有上"
      #                   "当。\n" NOR"], "success": ["= HIR "结果$p" HIR "顿时被$P" HIR "的鞭势牢牢缠住，"
      #                          "攻得措手不及！\n" NOR"]}, "resource_adds": [{"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("whip") / 22 + 1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("whip") / 22 + 1);
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
      # #define CHAN "「" HIW "缠字诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #         object weapon;
      # 
      #         if (userp(me) && ! me->query("can_perform/yunlong-bian/chan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(CHAN "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || weapon->query("skill_type") != "whip")
      #                 return notify_fail("你使用的武器不对，难以施展" CHAN "。\n");
      # 
      #     if ((int)me->query_skill("yunlong-bian",1) < 50)
      #         return notify_fail("你云龙鞭法火候太浅，难以施展" CHAN "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "yunlong-bian")
      #                 return notify_fail("你没有激发云龙鞭法，难以施展" CHAN "。\n");
      # 
      #     if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query("neili") < 50)
      #                 return notify_fail("你现在的真气不足，难以施展" CHAN "。\n");
      # 
      #         if (! living(target))
      #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = WHT "$N" WHT "使出云龙鞭法「缠」字诀，连挥" + weapon->name() +
      #               WHT"企图把$n"  WHT "的全身缠住。\n" NOR;
      # 
      #     if (random(me->query_skill("whip")) > target->query_skill("parry") / 2)
      #         {
      #         msg += HIR "结果$p" HIR "顿时被$P" HIR "的鞭势牢牢缠住，"
      #                        "攻得措手不及！\n" NOR;
      #         target->start_busy((int)me->query_skill("whip") / 22 + 1);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，并没有上"
      #                 "当。\n" NOR;
      #     }
      #         me->add("neili", -30);
      #     me->start_busy(2);
      #     message_combatd(msg, me, target);
      #     return 1;
      # }
end

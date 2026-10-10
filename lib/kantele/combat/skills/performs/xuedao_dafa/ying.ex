defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Ying do
  @moduledoc """
  perform「无影神刀」（source xuedao-dafa/ying.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "160"}, {"xuedao-dafa", "120"}], "map_gates": [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的血刀大法还不到家，难以施展", "你没有激发血刀大法为内功，难以施展", "你没有激发血刀大法为刀法，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "看破了$P" CYN "的企图"
      #                          "，并不慌张，应对自如。\n" NOR"], "success": ["WHT "$N" WHT "一声狞笑，将手中的" + weapon->name() +
      #                 WHT "舞动如轮，刀锋激起层层" HIR "血浪" NOR +
      #                 WHT "紧逼$n" WHT "而去。\n" NOR", "= HIR "结果$p" HIR "被$P" HIR "逼得手忙脚"
      #                          "乱，只能紧守门户，不敢擅动。\n" NOR"]}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("blade") / 27 + 2);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("blade") / 27 + 2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define YING "「" HIR "无影神刀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/xuedao-dafa/ying"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YING "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "blade")
      #                 return notify_fail("你使用的武器不对，难以施展" YING "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((int)me->query_skill("force") < 160)
      #                 return notify_fail("你的内功火候不够，难以施展" YING "。\n");
      # 
      #         if ((int)me->query_skill("xuedao-dafa", 1) < 120)
      #                 return notify_fail("你的血刀大法还不到家，难以施展" YING "。\n");
      # 
      #         if (me->query_skill_mapped("force") != "xuedao-dafa")
      #                 return notify_fail("你没有激发血刀大法为内功，难以施展" YING "。\n");
      # 
      #         if (me->query_skill_mapped("blade") != "xuedao-dafa")
      #                 return notify_fail("你没有激发血刀大法为刀法，难以施展" YING "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你的真气不够，难以施展" YING "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "一声狞笑，将手中的" + weapon->name() +
      #               WHT "舞动如轮，刀锋激起层层" HIR "血浪" NOR +
      #               WHT "紧逼$n" WHT "而去。\n" NOR;
      # 
      #         me->add("neili", -80);
      #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
      #         {
      #                 msg += HIR "结果$p" HIR "被$P" HIR "逼得手忙脚"
      #                        "乱，只能紧守门户，不敢擅动。\n" NOR;
      #                 target->start_busy((int)me->query_skill("blade") / 27 + 2);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图"
      #                        "，并不慌张，应对自如。\n" NOR;
      #                 me->start_busy(1);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

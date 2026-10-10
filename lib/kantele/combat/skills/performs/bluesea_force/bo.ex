defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Bo do
  @moduledoc """
  perform「bo」（source bluesea-force/bo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "bluesea-force"}, {"dp", "parry"}], "level_gates": [{"bluesea-force", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["碧海清波只能对战斗中的对手使用。\n", "你的南海玄功不够深厚，不会使用碧海清波。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("bluesea-force", 1) * 3 / 2 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("parry") +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "掌力忽左忽右，形成一个个气旋，如波浪一般接连向$n"
      #                 HIC "逼去！\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的掌势来路，"
      #                          "镇定自若，应对自如。\n" NOR"], "success": ["= HIR "结果$p" HIR "被$P" HIR "逼得施展不开半点招式！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 45 + 2);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 45 + 2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // bo.c 碧海清波
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #         int ap, dp;
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail("碧海清波只能对战斗中的对手使用。\n");
      # 
      #     if (target->is_busy())
      #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      # 
      #     if ((int)me->query_skill("bluesea-force", 1) < 100)
      #         return notify_fail("你的南海玄功不够深厚，不会使用碧海清波。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIC "$N" HIC "掌力忽左忽右，形成一个个气旋，如波浪一般接连向$n"
      #               HIC "逼去！\n" NOR;
      # 
      #         ap = me->query_skill("bluesea-force", 1) * 3 / 2 +
      #              me->query_skill("martial-cognize", 1);
      #         dp = target->query_skill("parry") +
      #              target->query_skill("martial-cognize", 1);
      # 
      #     if (ap / 2 + random(ap) > dp)
      #         {
      #         msg += HIR "结果$p" HIR "被$P" HIR "逼得施展不开半点招式！\n" NOR;
      #         target->start_busy(ap / 45 + 2);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的掌势来路，"
      #                        "镇定自若，应对自如。\n" NOR;
      #         me->start_busy(1);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end

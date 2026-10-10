defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Mie do
  @moduledoc """
  perform「mie」（source bluesea-force/mie.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "bluesea-force"}], "level_gates": [{"bluesea-force", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["五阴焚灭只能在战斗中对对手使用。\n", "你的南海玄功还不够娴熟，不能使用五阴焚灭！\n", "你的真气不够！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("bluesea-force")", "dp_formula": "target->query("combat_exp") / 10000"}, "color_codes": ["HIC", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "暴喝一声，变掌为爪，迅捷无比的袭向$n！\n"", "= HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR", "= HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
      #                         "然没有一点伤害，侥幸得脱！\n" NOR"], "success": ["= HIR "这一招完全超出了$n" HIR "的想象，被$N"
      #                          HIR "结结实实的抓中了气海穴，浑身真气登时涣散！\n" NOR"]}, "exp_compare": [{"ap", "dp"}], "resource_adds": [{"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // mie.c 五阴焚灭
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
      #             return notify_fail("五阴焚灭只能在战斗中对对手使用。\n");
      # 
      #     if (me->query_skill("bluesea-force", 1) < 150)
      #         return notify_fail("你的南海玄功还不够娴熟，不能使用五阴焚灭！\n");
      # 
      #     if (me->query("neili") < 300)
      #         return notify_fail("你的真气不够！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "暴喝一声，变掌为爪，迅捷无比的袭向$n！\n";
      # 
      #         ap = me->query_skill("bluesea-force");
      #         dp = target->query("combat_exp") / 10000;
      #     me->add("neili", -60);
      #     me->start_busy(1 + random(2));
      # 
      #     me->want_kill(target);
      #         if (dp >= 100)
      #         {
      #                 msg += HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR;
      #         } else
      #         if (random(ap) > dp)
      #         {
      #                 msg += HIR "这一招完全超出了$n" HIR "的想象，被$N"
      #                        HIR "结结实实的抓中了气海穴，浑身真气登时涣散！\n" NOR;
      #                 message_combatd(msg, me, target);
      #                 target->die(me);
      #                 return 1;
      #         } else
      #         {
      #                 msg += HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
      #                       "然没有一点伤害，侥幸得脱！\n" NOR;
      #         }
      # 
      #         message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.Hamagong.Tui do
  @moduledoc """
  exert「tui」（source hamagong/tui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}, {"skill", "hamagong"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "4000"}, {"neili", "1000"}], "var_gates": [{"dp", "1"}, {"skill", "240"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["蛤蟆功「推天式」只能对战斗中的对手使用。\n", "你的蛤蟆功修为不够精深，不能使用「推天式」！\n", "你的内力修为不够深厚，无法施展「推天式」！\n", "你的真气不够，无法运用「推天式」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") * 15 + me->query("max_neili")", "dp_formula": "1"}, "color_codes": ["CYN", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "蹲在地上，“嗝”的一声大叫，双手弯"
      #                 "与肩齐，平推而出，一股极大的力道如同"
      #                 "排山倒海一般奔向$n" HIY "。\n" NOR", "= HIG "然而$p" HIG "哈哈一笑，随手一指刺出，正是一"
      #                          "阳指的精妙招数，轻易的化解了$P" HIG "的攻势。\n" NOR", "= CYN "可是$n" CYN "将内力运到双臂上，接下了$P"
      #                          CYN "这一推之式，只听“蓬”的一声，震得四周"
      #                          "尘土飞扬。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "奋力低档，但是$P" HIR "的来势何"
      #                                              "等浩大，$p" HIR "登时觉得气血不畅，“哇”的"
      #                                              "吐出了一口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "(ap - dp) / 10 + random(ap / 10)"}, "hit_formula": %{"left_side": "(ap / 2 + random(ap)", "operator": ">", "right_side": "dp)&&(ap>dp)"}, "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);", "me->start_busy(3);", "target->start_busy(1);"], "remote_damage": true, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(2);
      #   - me->start_busy(3);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

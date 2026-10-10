defmodule Kantele.Combat.Skills.Performs.QixianWuxingjian.Shan do
  @moduledoc """
  perform「七弦黄龙闪」（source qixian-wuxingjian/shan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}, {"skill", "qixian-wuxingjian"}], "level_gates": [{"force", "250"}], "map_gates": [{"sword", "qixian-wuxingjian"}], "prepared_gates": [{"unarmed", "qixian-wuxingjian"}], "resource_gates": [{"max_neili", "10"}, {"neili", "600"}], "var_gates": [{"skill", "160"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的七弦无形剑修为有限，难以施展", "你没有准备七弦无形剑，难以施展", "你没有准备七弦无形剑，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$n" CYN "急忙凝神聚气，努力使自己"
      #                          "不受琴音的干扰，终于化解了这一招。\n" NOR"], "other": ["HIY "只见$N" HIY "一声暴喝，单手迅速在" + weapon->name() +
      #                         HIY "上拨动数下，顿时琴音铮铮大响，只听“啵”的\n一声破空"
      #                         "之响，一束无形剑气澎湃射出，直贯$n" HIY "而去。\n" NOR", "HIY "只见$N" HIY "一声暴喝，陡然间十指一并箕张，顿时琴音"
      #                         "铮铮大响，只听“啵”的一声破空之\n响，一束无形剑气澎湃"
      #                         "射出，直贯$n" HIY "而去。\n" NOR", "= HIY "$N" HIY "这一招施出，可是$n"
      #                          HIY "竟像没事一般，丝毫无损。\n" NOR", "= HIY "可是$n" HIY "内力深厚，轻而易举受下$N"
      #                          HIY "这一招，丝毫无损。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 100,
      #                                              HIR "$n" HIR "只觉得$N" HIR "内力激荡，琴"
      #                                              "音犹如一柄利剑穿透鼓膜，“哇”的喷出一口"
      #                                              "鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "ap + skill"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);", "me->start_busy(2);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(2);
      #   - me->start_busy(2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

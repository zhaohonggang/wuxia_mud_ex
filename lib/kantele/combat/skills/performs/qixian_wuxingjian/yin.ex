defmodule Kantele.Combat.Skills.Performs.QixianWuxingjian.Yin do
  @moduledoc """
  perform「七弦无形音」（source qixian-wuxingjian/yin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你七弦无形剑修为有限，难以施展", "你没有准备七弦无形剑，难以施展", "你没有准备七弦无形剑，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$n" CYN "急忙凝神聚气，努力使自己"
      #                          "不受琴音的干扰，终于化解了这一招。\n" NOR"], "other": ["HIM "只见$N" HIM "一声冷哼，以内劲催动" + weapon->name()
      #                         + HIM "，激荡出无形琴音，铮然大响，只听“啵”的\n一声破空"
      #                         "之响，一束无形剑气澎湃射出，直贯$n" HIM "而去。\n" NOR", "HIM "只见$N" HIM "一声冷哼，狂催内劲激荡出无形琴音，铮"
      #                         "然大响，只听“啵”的一声破空之\n响，一束无形剑气澎湃"
      #                         "射出，直贯$n" HIM "而去。\n" NOR", "= HIM "$N" HIM "这一招施出，可是$n"
      #                          HIM "竟像没事一般，丝毫无损。\n" NOR", "= HIM "可是$n" HIM "内力深厚，轻而易举受下$N"
      #                          HIM "这一招，丝毫无损。\n" NOR"], "success": ["= HIR "$n" HIR "只觉得$N" HIR "内力激荡，琴"
      #                          "音犹如一柄利剑穿透鼓膜，“哇”的喷出一口"
      #                          "鲜血。\n""]}, "damage_formula": %{"formula": "ap + skill"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": "<", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 3", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-100"}, {"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);", "me->start_busy(2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
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

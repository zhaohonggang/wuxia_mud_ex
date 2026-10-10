defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Shi do
  @moduledoc """
  perform「shi」（source chousui-zhang/shi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"lvl", "chousui-zhang"}, {"lvp", "poison"}], "level_gates": [{"throwing", "180"}], "map_gates": [{"strike", "chousui-zhang"}], "prepared_gates": [{"strike", "chousui-zhang"}], "resource_gates": [{"max_neili", "1200"}, {"neili", "500"}], "var_gates": [{"lvl", "140"}, {"lvl", "200"}, {"lvl", "250"}, {"lvp", "200"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "corpse_poison", "duration_formula": "5 + random(lvp / 20)", "id_formula": "me->query("id")", "level_formula": "lvp + random(lvp)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的抽髓掌不够娴熟，难以施展", "你对毒技的了解不够，难以施展", "你暗器手法火候不够，难以施展", "你没有激发抽髓掌，难以施展", "你没有准备抽髓掌，难以施展", "你的内力修为不足，难以施展", "你现在的内息不足，难以施展", "你附近没有合适的尸体，难以施展", "你附近没有合适的尸体，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") +
      #                //me->query_skill("poison")", "dp_formula": "target->query_skill("dodge") +
      #                        //target->query_skill("parry")"}, "callback_functions": [%{"body": "//int lvp = me->query_skill("poison") * 2 / 3;
      #           int lvp = me->query_skill("poison",1);
      #   
      #           target->affect_by("corpse_poison",
      #                   ([ "level"    : lvp + random(lvp),
      #              ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 75,
      #                                             (: final, me, target, damage :))", "= CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
      #                          "于避开了$N" CYN "掷来的尸体。\n" NOR"], "success": ["WHT "$N" WHT "随手抓起" + name + WHT "，将「"
      #                 HIR "腐尸毒" NOR + WHT"」毒质运于其上，朝$n"
      #                 WHT "猛掷而去。\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "REMOTE_ATTACK", "callback": "final", "damage_factor": 75, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": ["corpse_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

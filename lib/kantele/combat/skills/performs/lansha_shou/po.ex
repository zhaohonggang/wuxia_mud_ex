defmodule Kantele.Combat.Skills.Performs.LanshaShou.Po do
  @moduledoc """
  perform「破靛神砂」（source lansha-shou/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "force"}, {"lvl", "lansha-shou"}], "level_gates": [{"force", "150"}, {"lansha-shou", "100"}], "map_gates": [{"hand", "lansha-shou"}], "prepared_gates": [{"hand", "lansha-shou"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "sha_poison", "duration_formula": "lvl / 50 + random(lvl / 30)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你蓝砂手不够熟练，难以施展", "你的内力修为不足，难以施展", "你没有激发蓝砂手，难以施展", "你没有准备蓝砂手，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("force")"}, "callback_functions": [%{"body": "int lvl = me->query_skill("lansha-shou", 1) / 2 * 3;
      #   
      #           target->affect_by("sha_poison",
      #                   ([ "level"    : me->query("jiali") + random(me->query("jiali")),
      #                      "id"  ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIB", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "$n" CYN "见$N"
      #                          CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR"], "other": ["HIG "$N" HIG "身形急转，宛若鬼魅，悄然施出蓝砂手绝技「" NOR +
      #                 HIB "破靛神砂" NOR + HIG "」，朝$n" HIG "胸前大穴抓落！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                             (: final, me, target, damage :))"], "success": []}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "do_damage_calls": [%{"attack_type": "UNARMED_ATTACK", "callback": "final", "damage_factor": 20, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": ["sha_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Xin do
  @moduledoc """
  perform「摄心大法」（source jiuyin-shengong/xin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jiuyin-shengong"}, {"dp", "martial-cognize"}], "level_gates": [{"force", "280"}, {"jiuyin-shengong", "280"}, {"martial-cognize", "200"}], "map_gates": [{"force", "jiuyin-shengong"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你九阴神功不够娴熟，难以施展", "你内功根基不够，难以施展", "你没有激发九阴神功为内功，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jiuyin-shengong", 1) + me->query_skill("force", 1)", "dp_formula": "target->query_skill("martial-cognize", 1) + target->query_skill("force", 1)"}, "callback_functions": [%{"body": "if (!objectp(target) || !target->query_temp("eff/jiuyin-shengong/xin"))
      #           return;
      #       target->delete_temp("eff/jiuyin-shengong/xin");
      #       tell_object(target, HIW "猛然间你气血上冲，头昏胀痛之感顿然消去，精力逐渐集中起来。\n", "name": "remove_effs", "params": "object target", "return_type": "void"}], "color_codes": ["CYN", "HIG", "HIM", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIG "$n" HIG "登时觉得胸口苦闷之极，心神难以自制，喜怒哀乐竟全随着$N" HIG
      #                      "而变。顷刻之间，$n" HIG "顿觉精力不济，头晕目眩。\n" NOR", "= NOR + CYN "$n" NOR + CYN "怒喝道：“尔等妖法，休想迷惑我！”。猛然间，招式陡快，"
      #                                           "竟将$N" NOR +
      #                  CYN "这招破去。\n" NOR"], "success": ["HIM "\n$N" HIM "猛然间尖啸一声，施展出九阴神功中的「" HIR "摄心大法" HIM "」。"
      #                 "只见$N" HIM "各种招式千奇百怪、变化多端，脸上喜怒哀乐，怪状百出。\n" NOR"]}, "hit_formula": %{"left_side": "ap * 11 / 20 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "ap / 2 + random(ap / 4)", "kind": "damage", "part": "jing", "source": None}, %{"formula": "ap / 2 + random(ap / 8)", "kind": "wound", "part": "jing", "source": None}], "resource_adds": [{"neili", "-200"}, {"neili", "-400"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(4));", "target->start_busy(2 + random(4));", "me->start_busy(1 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(4));
      #   - target->start_busy(2 + random(4));
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

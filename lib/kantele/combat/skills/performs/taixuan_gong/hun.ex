defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Hun do
  @moduledoc """
  perform「混天一气」（source taixuan-gong/hun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "taixuan-gong"}, {"dp", "force"}], "level_gates": [{"taixuan-gong", "200"}], "map_gates": [{"force", "taixuan-gong"}, {"unarmed", "taixuan-gong"}], "prepared_gates": [{"unarmed", "taixuan-gong"}], "resource_gates": [{"neili", "600"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的太玄功还不够娴熟，难以施展", "你现在没有激发太玄功为拳脚，难以施展", "你现在没有激发太玄功为内功，难以施展", "你现在没有准备使用太玄功，难以施展", "你的内力不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("taixuan-gong", 1) * 2 + me->query("con") * 10 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("force") + target->query("con") * 10 +
      #                target->query_skill("martial-cognize", 1)"}, "callback_functions": [%{"body": "target->receive_damage("jing", damage / 2, me);
      #           target->receive_wound("jing", damage / 3, me);
      #           target->busy(1);
      #           return  HIR "$n" HIR "急忙飞身后退，可是气流射"
      #                   "得更快，只听$p" H", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIG", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "双手合十，双目微闭，太玄奥义自心底涌出，猛然间，$N"
      #                 HIG "双手向前推出，一股强劲的气流袭向$n " HIG "。\n" NOR", "= HIY "然而$n" HIY "全力抵挡，终于将$N" HIY
      #                          "发出的气流挡住。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80 + random(5),
      #                                              (: final, me, target, damage :))"], "success": []}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 2", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 3", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-(me->query_skill("taixuan-gong", 1) +
      #                               random(me->query_skill("taixuan-gong", 1)))"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

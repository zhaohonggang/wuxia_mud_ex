defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Po do
  @moduledoc """
  perform「乘风破浪」（source taixuan-gong/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"taixuan-gong", "260"}], "map_gates": [{"force", "taixuan-gong"}], "prepared_gates": [{"unarmed", "taixuan-gong"}], "resource_gates": [{"max_neili", "8500"}, {"neili", "0"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力的修为不够，现在无法使用", "你的太玄功还不够娴熟，难以施展", "你现在没有激发太玄功为内功，难以施展", "你现在没有准备使用太玄功，难以施展", "你的真气不够，无法运用"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force", 1) +
      #                me->query_skill("unarmed", 1) +
      #                me->query_skill("martial-cognize", 1) +
      #                me->query_skill("taixuan-gong", 1) +
      #                me->query("con") * 10", "dp_formula": "obs[i]->query_skill("force") * 2 +
      #                        obs[i]->query_skill("martial-cognize", 1) +
      #                        obs[i]->query("con") * 10"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW"仰望天际，心中思绪万千。忽然间，$N" HIW "一声长叹，"
      #                 "随即双掌不停地拍出，侠客岛石壁上的太玄图谱已一幅幅涌上心头，"
      #                 "霎那间四周狂风骤起，尘土飞扬，气势如虹。这正是太玄功绝招「"
      #                 NOR + HIC "乘风破浪" NOR + HIW "」。转眼间，$N" HIW "双掌越发"
      #                 "凌厉，已不知不觉地将四周笼罩，当真令人胆战心惊。\n" NOR", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n""], "success": ["HIR "只听" + obs[i]->name() +
      #                                         HIR "一声惨嚎，接连退了数步，“"
      #                                         "哇”的呕出一大口鲜血。\n" NOR", "HIR "只见" + obs[i]->name() +
      #                                         HIR "向后飞出丈远，重重的跌落在"
      #                                         "地上，衣衫破烂，再也无法站起来"
      #                                         "。\n" NOR", "HIR "只见" + obs[i]->name() +
      #                                         HIR "歪歪斜斜倒退几步，伏倒"
      #                                         "在地，痛苦不堪。"
      #                                         "。\n" NOR", "HIR "狂风卷过，" + obs[i]->name() +
      #                                         HIR "只见，飞沙狂舞，却动也动不了"
      #                                         "忽然间，却瘫软在地。\n" NOR", "HIR + obs[i]->name() +
      #                                         HIR "急忙飞身而起，却猛然坠地，伤痕遍体，鲜"
      #                                         "血不止。\n" NOR"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage * 2 / 3", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 6", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-(sizeof(obs) * 220)"}, {"neili", "-500"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(5);", "obs[i]->start_busy(1);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(5);
      #   - obs[i]->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

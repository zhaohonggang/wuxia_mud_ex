defmodule Kantele.Combat.Skills.Performs.TaijiQuan.Tu do
  @moduledoc """
  perform「太极图」（source taiji-quan/tu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "taoism"}, {"dp", "force"}], "level_gates": [{"taiji-quan", "250"}, {"taiji-shengong", "300"}, {"taoism", "300"}], "map_gates": [{"force", "taiji-shengong"}, {"unarmed", "taiji-quan"}], "prepared_gates": [{"unarmed", "taiji-quan"}], "resource_gates": [{"jingli", "1000"}, {"neili", "0"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的太极拳不够娴熟，难以施展", "你的太极神功修为还不够高，难以施展", "你的道学心法修为还不够高，难以施展", "你现在没有激发太极拳，难以施展", "你现在没有激发太极神功，难以施展", "你没有准备使用太极拳，难以施展", "你现在精力不够，难以施展", "你现在真气不够，难以施展"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("taoism", 1) +
      #                me->query_skill("taiji-quan", 1) +
      #                me->query_skill("taiji-shengong", 1)", "dp_formula": "obs[i]->query_skill("force") * 2 +
      #                        obs[i]->query_skill("taoism", 1)"}, "color_codes": ["HIC", "HIM", "HIR", "HIW", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "淡然一笑，双手轻轻划了数个圈子，顿时四周的气"
      #                 "流波动，源源不断的被牵引进来。\n\n" NOR", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n""], "success": ["HIR "只见" + obs[i]->name() +
      #                                         HIR "手舞足蹈，忘乎所以，忽"
      #                                         "然大叫一声，吐血不止！\n" NOR", "HIR "却见" + obs[i]->name() +
      #                                         HIR "容貌哀戚，似乎想起了什"
      #                                         "么伤心之事，身子一晃，呕出数口鲜血！\n" NOR", "HIR + obs[i]->name() +
      #                                         HIR "呆立当场，一动不动，有如中"
      #                                         "邪，七窍都迸出鲜血来。\n" NOR"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 2", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "damage / 3", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 6", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-1000"}, {"neili", "-200"}, {"neili", "-500"}], "resource_queries": ["max_qi", "neili", "qi"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"jingli", "-1000"}, {"neili", "-1000"}, {"neili", "-200"}, {"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(4);", "obs[i]->start_busy(3);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(4);
      #   - obs[i]->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

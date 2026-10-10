defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Ri do
  @moduledoc """
  perform「魔光日无极」（source jiuyang-shengong/ri.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"jiuyang-shengong", "250"}], "map_gates": [{"force", "jiuyang-shengong"}, {"unarmed", "jiuyang-shengong"}], "prepared_gates": [{"unarmed", "jiuyang-shengong"}], "resource_gates": [{"max_neili", "8000"}, {"neili", "0"}, {"neili", "2000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内力的修为不够，现在无法使用", "你的九阳神功还不够娴熟，难以施展", "你现在没有激发九阳神功为拳脚，难以施展", "你现在没有激发九阳神功为内功，难以施展", "你现在没有准备使用九阳神功，难以施展", "你的真气不够，无法运用"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force", 1) +
      #                me->query_skill("unarmed", 1) +
      #                me->query_skill("martial-cognize", 1) +
      #                me->query_skill("jiuyang-shengong", 1) +
      #                me->query("con") * 10", "dp_formula": "obs[i]->query_skill("force") * 2 +
      #                        obs[i]->query_skill("martial-cognize", 1) +
      #                        obs[i]->query("con") * 10"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "只见$N" HIY "双目微闭，单手托天。掌心顿时腾起一个无比刺眼的"
      #                 "气团，正是奥\n义「" NOR + HIW "魔光日无极" NOR + HIY "」。霎时"
      #                 "金光万道，尘沙四起，空气炽热，几欲沸腾。$N" HIY "\n随即收拢掌心"
      #                 "，气团爆裂开来，向四周电射而出，光芒足以和日月争辉。\n\n" NOR", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n"", "= "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n""], "success": ["HIR "只听" + obs[i]->name() +
      #                                         HIR "一声惨嚎，接连退了数步，“"
      #                                         "哇”的呕出一大口鲜血。\n" NOR", "HIR "只见" + obs[i]->name() +
      #                                         HIR "向后飞出丈远，重重的跌落在"
      #                                         "地上，衣衫烧焦，再也没力气站起"
      #                                         "。\n" NOR", "HIR "只见" + obs[i]->name() +
      #                                         HIR "跌跌撞撞向后连退数步，伏倒"
      #                                         "在地。须眉、衣衫都发出一股焦臭"
      #                                         "。\n" NOR", "HIR "光芒闪过，" + obs[i]->name() +
      #                                         HIR "却是呆立当场，动也不动，七"
      #                                         "窍流血，神情扭曲，煞是恐怖。\n" NOR", "HIR + obs[i]->name() +
      #                                         HIR "急忙抽身后退，可只见眼前光"
      #                                         "芒暴涨，一闪而过。全身已多了数"
      #                                         "个伤口，鲜血飞溅。\n" NOR"]}, "damage_formula": %{"formula": "ap / 4 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 2", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "damage / 6", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 10", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-1000"}, {"neili", "-500"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-1000"}, {"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(5);", "obs[i]->start_busy(1);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(5);
      #   - obs[i]->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.XianglongZhang.Hui do
  @moduledoc """
  perform「亢龙有悔」（source xianglong-zhang/hui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "380"}, {"xianglong-zhang", "250"}], "map_gates": [{"strike", "xianglong-zhang"}], "prepared_gates": [{"strike", "xianglong-zhang"}], "resource_gates": [{"max_neili", "6000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你降龙十八掌火候不够，难以施展", "你没有激发降龙十八掌，难以施展", "你没有准备降龙十八掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 10", "dp_formula": "target->query_skill("force") + target->query("con") * 10"}, "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "却见$p气贯双臂，凝神应对，$P掌"
      #                         "力如泥牛入海，尽数卸去。\n" NOR", "HIC "可是$p全力抵挡招架，竟似游刃有"
      #                         "余，将$P的掌力卸于无形。\n" NOR", "HIC "$p眼见来势凶猛，身形疾退，瞬间"
      #                         "飘出三丈，脱出掌力之外。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60 + random(10),
      #                                             HIR "$P身形一闪，竟已晃至$p跟前，$p躲"
      #                                             "闪不及，顿被击个正中。\n" NOR)", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(10),
      #                                             HIR "$p一声惨嚎，被$P这一掌击中胸前，"
      #                                             "喀嚓喀嚓断了几根肋骨。\n" NOR)", "COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80 + random(10),
      #                                             HIR "结果$p躲闪不及，$P掌劲顿时穿胸而"
      #                                             "过，顿时口中鲜血狂喷。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400 - random(400)"}, {"neili", "-400 - random(600)"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Zhugu do
  @moduledoc """
  perform「zhugu」（source qianzhu-wandushou/zhugu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "hand"}, {"poison", "poison"}], "level_gates": [{"force", "200"}, {"qianzhu-wandushou", "130"}], "map_gates": [{"hand", "qianzhu-wandushou"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "qianzhu_wandushou", "duration_formula": "lvl / 40 + random(lvl / 18)", "id_formula": "me->query("id")", "level_formula": "lvl * 2 / 3 + random(poison)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "这里不能攻击别人！\n", "你要对谁施展蛛蛊决？\n", "看清楚，那不是活人。\n", "你的内功火候不足以施展蛛蛊决。\n", "你的千蛛万毒手修为不够，现在还无法施展蛛蛊决。\n", "你没有激发千蛛万毒手，无法施展蛛蛊决。\n", "你的真气不够，现在无法施展蛛蛊决。\n"], "color_codes": ["CYN", "HIB", "HIR", "NOR"], "combat_exp_formulas": [{"lvls", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "运足内力，以深厚的内功"
      #                          "化解了这一指的毒劲。\n" NOR"], "other": ["HIB "$N" HIB "施出蛛蛊决，只见一缕黑气从"
      #                 "指尖透出，只一闪就没入了$n" HIB "的眉心！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50 + poison,
      #                                              HIR "$p" HIR "只觉得一股如山的劲力顺指尖猛"
      #                                              "攻过来，只觉得全身毒气狂窜，“哇”的一声"
      #                                              "吐出一口黑血！\n" NOR)"]}, "damage_formula": %{"formula": "lvl + random(lvl / 2)"}, "resource_adds": [{"neili", "-200"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-80"}], "affect_by": ["qianzhu_wandushou"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

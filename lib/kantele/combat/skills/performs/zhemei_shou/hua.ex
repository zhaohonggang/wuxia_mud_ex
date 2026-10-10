defmodule Kantele.Combat.Skills.Performs.ZhemeiShou.Hua do
  @moduledoc """
  perform「化妖功」（source zhemei-shou/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "dodge"}, {"dp", "dodge"}, {"lv", "zhemei-shou"}], "level_gates": [{"beiming-shengong", "220"}, {"xiaowuxiang", "220"}, {"zhemei-shou", "220"}], "map_gates": [{"force", "beiming-shengong"}, {"force", "xiaowuxiang"}, {"hand", "zhemei-shou"}], "prepared_gates": [{"hand", "zhemei-shou"}], "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的逍遥内功火候不够，难以施展", "你逍遥折梅手等级不够，难以施展", "你的内力修为不足，难以施展", "你没有激发逍遥内功，难以施展", "你没有激发逍遥折梅手，难以施展", "你没有准备逍遥折梅手，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("dodge") + me->query_skill("hand")", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIM", "HIR", "NOR", "RED"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIM "$N" HIM "深深吸进一口气，单手挥出，掌缘顿时霞光万道，漾出"
      #                 "七色虹彩向$n" HIM "席卷而至。\n" NOR", "= HIM "只听$n" HIM "一声尖啸，$N" HIM "的七色掌"
      #                                  "劲已尽数注入$p" HIM "体内，顿时将$p" HIM "化"
      #                                  "为一滩血水。\n" NOR "( $n" RED "受伤过重，已"
      #                                  "经有如风中残烛，随时都可能断气。" NOR ")\n"", "= HIM "$n" HIM "只是微微一愣，$N" HIM "的七色掌劲已破体而"
      #                                  "入，$p" HIM "便犹如身置洪炉一般，连呕数口鲜血。\n" NOR", "= "( $n" + eff_status_msg(p) + " )\n"", "= CYN "$p" CYN "见状大惊失色，完全勘破不透$P"
      #                          CYN "招中奥秘，当即飞身跃起丈许，躲闪开来。\n" NOR"], "success": []}, "damage_formula": %{"formula": "0"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap) + random(20)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 2", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-200"}, {"neili", "cost_neili"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(2);", "me->start_busy(3);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.HuanyinZhi.Huanyin do
  @moduledoc """
  perform「huanyin」（source huanyin-zhi/huanyin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "finger"}], "level_gates": [{"force", "300"}, {"huanyin-zhi", "150"}], "map_gates": [{"finger", "huanyin-zhi"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "huanyin_poison", "duration_formula": "lvl / 40 + random(lvl / 18)", "id_formula": "me->query("id")", "level_formula": "lvl / 2 + random(lvl / 2)"}], "all_fail_messages": ["这里不能攻击别人! \n", "幻阴神指只能对对手使用。\n", "看清楚，那不是活人。\n", "你的内功火候不足以施展幻阴神指。\n", "你的幻阴指法修为不够，现在还无法施展幻阴神指。\n", "你没有激发幻阴指法，无法施展幻阴神指。\n", "你的真气不够，现在无法施展幻阴神指。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "NOR"], "combat_messages": %{"fail": ["= CYN "可是$p" CYN "运足内力，以深厚的内功"
      #                          "化解了这一指的阴寒内力。\n" NOR"], "other": ["HIG "$N" HIG "深深的吸了一口气，缓缓的刺"
      #                 "出一指，挟带一股寒气逼向$n" HIG "。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                                              HIG "$p" HIG "急忙后退，然而这指何等玄妙，正"
      #                                              "好点中$p" HIG "胸前，$p" HIG "不禁打了一个冷"
      #                                              "战。\n" NOR)"], "success": []}, "damage_formula": %{"formula": "lvl + random(lvl / 2)"}, "resource_adds": [{"neili", "-320"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-320"}, {"neili", "-80"}], "affect_by": ["huanyin_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

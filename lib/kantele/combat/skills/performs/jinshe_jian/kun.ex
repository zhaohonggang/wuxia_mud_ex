defmodule Kantele.Combat.Skills.Performs.JinsheJian.Kun do
  @moduledoc """
  perform「蛇困愁城」（source jinshe-jian/kun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "jinshe-jian"}], "level_gates": [], "map_gates": [{"sword", "jinshe-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"level", "140"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你金蛇剑法不够娴熟，难以施展", "你没有激发金蛇剑法，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "轻叹一声，手中" + weapon->name() + HIG "犹如"
      #                 "金蛇般的缠向$n" HIG "。\n" NOR", "HIY "一道金光闪过，$n已被$N" HIY "攻的目不暇接，手忙脚乱！\n" NOR", "CYN "可是$n" CYN "看破了$N"
      #                         CYN "的企图，镇定解招，一丝不乱。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-140"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-140"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(1 + random(level / 13));", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(1 + random(level / 13));
      #   - me->start_busy(1);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

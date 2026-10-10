defmodule Kantele.Combat.Skills.Performs.LongchengShendao.Fengyu do
  @moduledoc """
  perform「fengyu」（source longcheng-shendao/fengyu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "longcheng-shendao"}], "level_gates": [{"force", "150"}, {"longcheng-shendao", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "270"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你不会使用「风雨交加」。\n", "「风雨交加」只能对战斗中的对手使用。\n", "施展「风雨交加」手中必须拿着一把刀！\n", "你的真气不够，无法施展「风雨交加」！\n", "你的内功火候不够，无法施展「风雨交加」！\n", "你的龙城神刀还不到家，无法使用绝技「风雨交加」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "大喝一声，手中的" + weapon->name() + HIC
      #                 "如雨点一般向$n" HIC "打去，$n" HIC "如同小舟一般在刀雨中漂泊不定。\n" NOR", "= HIY "这阵刀势变化莫测，$n" HIY "顿时觉得眼花缭乱，无法抵挡。\n" NOR", "= HIC "$n" HIC "不禁心中凛然，不敢有半点小觑，使出浑身解数抵挡。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

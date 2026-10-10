defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Chang3 do
  @moduledoc """
  perform「chang3」（source shedao-qigong/chang3.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"shedao-qigong", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["唱仙法吼字决只能在战斗中对对手使用。\n", "你的蛇岛奇功不够娴熟，不会使用唱仙法吼字决。\n", "在这里不能攻击他人。\n", "你已经精疲力竭，真气不够了。\n", "敌人的内力不逊于你，伤不了！\n"], "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "damage_formula": %{"formula": "(neili - (int)target->query("max_neili")) / 10"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "qi", "source": "me"}, %{"formula": "10", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-(300 + random(200))"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

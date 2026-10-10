defmodule Kantele.Combat.Skills.Performs.DacidabeiShou.Yin do
  @moduledoc """
  perform「yin」（source dacidabei-shou/yin.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "dacidabei-shou"}], "level_gates": [{"buddhism", "200"}, {"dacidabei-shou", "180"}, {"hand", "180"}], "map_gates": [], "prepared_gates": [{"hand", "dacidabei-shou"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的佛法修为不足，无法施展该绝招！\n", "「大手印」只能在战斗中对对手使用。\n", "你的大慈大悲手不够娴熟，不会使用「大手印」！\n", "你的基本手法不够娴熟，不会使用「大手印」！\n", "你的臂力不够强，不能使用「大手印」！\n", "你的内力太弱，不能使用「大手印」！\n", "你的内力太少了，无法使用出「大手印」！\n", "你还没有准备大慈大悲手，无法施展「大手印」！\n", "你必须空手使用「大手印」！\n"], "color_codes": ["HIR", "HIY", "NOR", "RED"], "combat_messages": %{"fail": [], "other": [""( $n"+eff_status_msg(p)+" )\n""], "success": []}, "damage_formula": %{"formula": "me->query_skill("dacidabei-shou", 1)/40 * jiali"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage/3", "kind": "wound", "part": "qi", "source": "me"}], "reset_action": true, "resource_adds": [{"neili", "-200"}, {"neili", "-jiali"}], "resource_queries": ["max_neili", "max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "wield_actions": ["unequip"]}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2+random(2));"], "remote_damage": false, "set_flags": [{"value", "0"}], "temp_set": []}
      #   - me->start_busy(2+random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

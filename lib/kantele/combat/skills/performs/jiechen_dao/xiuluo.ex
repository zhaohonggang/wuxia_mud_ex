defmodule Kantele.Combat.Skills.Performs.JiechenDao.Xiuluo do
  @moduledoc """
  perform「xiuluo」（source jiechen-dao/xiuluo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"i", "force"}], "level_gates": [{"blade", "180"}, {"hunyuan-yiqi", "140"}, {"jiechen-dao", "180"}], "map_gates": [{"blade", "jiechen-dao"}, {"force", "hunyuan-yiqi"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「修罗焰」攻击只能对战斗中的对手使用。\n", "你先找把刀再说吧！\n", "你必须使用戒尘刀来施展「修罗焰」。\n", "你的戒尘刀火候还嫌不够，这「修罗焰」绝技不用也罢。\n", "你的基本刀法还不够娴熟，使不出「修罗焰」绝技。\n", "你的心意气混元功等级不够，使不出「修罗焰」绝技。\n", "你的身体还不够强壮，强使「修罗焰」绝技是引火自焚！\n", "你现在这内功平平无奇，如何使得出「修罗焰」绝技来！？\n", "你的内力修为不够，这「修罗焰」绝技不用也罢。\n", "以你目前的内力来看，这「修罗焰」绝技不用也罢。\n"], "buff_delete": ["xiuluo"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1+random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1+random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

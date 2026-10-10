defmodule Kantele.Combat.Skills.Performs.DuanjiaSword.Jue do
  @moduledoc """
  perform「jue」（source duanjia-sword/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"duanjia-sword", "100"}, {"force", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你现在还不会使用五绝剑！\n", "段家五绝剑只能对战斗中的对手使用。\n", "你必须持剑或杖才能施展段家五绝剑！\n", "你的真气不够！\n", "你的内功火候不够！\n", "你的段家剑法还不到家，无法使用五绝剑！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "深吸一口气，脚下步步进击，稳重之极，手中的" +
      #                 weapon->name() + HIY "使得犹如飞龙一般，缠绕向$n" HIY "！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(5) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Wan do
  @moduledoc """
  perform「wan」（source qianzhu-wandushou/wan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"poison", "poison"}, {"skill", "qianzhu-wandushou"}], "level_gates": [{"force", "300"}], "map_gates": [], "prepared_gates": [{"hand", "qianzhu-wandushou"}], "resource_gates": [{"max_neili", "3500"}, {"neili", "500"}], "var_gates": [{"i", "5"}, {"skill", "220"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "「万蛊噬天」只能对战斗中的对手使用。\n", "对方都已经这样了，用不着这么费力吧？\n", "你没有准备使用千蛛万毒手，无法施展万蛊噬天。\n", "你的千蛛万毒手修为有限，无法施展万蛊噬天。\n", "你的内功火候不够，难以施展万蛊噬天。\n", "你的内力修为没有达到那个境界，无法运转内力施展万蛊噬天。\n", "你的真气不够，现在无法施展万蛊噬天。\n", "你必须是空手才能施展万蛊噬天。\n"], "color_codes": ["NOR", "RED"], "combat_messages": %{"fail": [], "other": ["RED "\n$N" RED "仰天一声长啸，强催内劲，全身"
      #                 "竟浮现出隐隐碧绿之色。喝道：“万蛊噬天”,双"
      #                 "掌猛\n然拍出，登时幻出漫天碧绿色掌影，毒气弥"
      #                 "漫，笼罩$n" RED "全身！\n\n" NOR"], "success": []}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["dodge", "parry", "unarmed_damage"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

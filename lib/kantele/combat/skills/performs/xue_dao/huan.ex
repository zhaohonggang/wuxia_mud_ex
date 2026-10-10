defmodule Kantele.Combat.Skills.Performs.XueDao.Huan do
  @moduledoc """
  perform「huan」（source xue-dao/huan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"xue-dao", "80"}], "map_gates": [{"blade", "xue-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "60"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["血刀刀法「幻影」只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的血刀刀法不够娴熟，不会使用「幻影」。\n", "你现在真气不够，无法使用「幻影」。\n", "你没有激发血刀刀法，不能使用「幻影」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "$N" HIR "使出血刀刀法绝技，把手中的" +
      #                 weapon->name() + HIR "舞得飞快，幻起层层刀影逼向$n"
      #                 HIR "！\n"", "= HIR "结果$p" HIR "被$P" HIR "闹个手忙脚乱，"
      #                          "只能紧守门户，不敢擅动！\n" NOR", "= "可是$p" HIR "看破了$P" HIR "的企图，并"
      #                          "不慌张，应对自如。\n" NOR"]}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("blade") / 27 + 2);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("blade") / 27 + 2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

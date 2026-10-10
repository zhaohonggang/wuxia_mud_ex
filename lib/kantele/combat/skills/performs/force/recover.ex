defmodule Kantele.Combat.Skills.Performs.Force.Recover do
  @moduledoc """
  exert「recover」（source force/recover.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [{"n", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "20"}], "var_gates": [{"n", "20"}, {"q", "10"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用内功调匀自己的气息。\n", "你的内力不够。\n", "你现在气力充沛。\n"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "q", "kind": "heal", "part": "qi", "source": None}], "resource_adds": [{"neili", "-n"}], "resource_queries": ["neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // recover.c
      # 
      # int exert(object me, object target)
      # {
      #     int n, q;
      # 
      #     if (me != target)
      #         return notify_fail("你只能用内功调匀自己的气息。\n");
      # 
      #     if ((int)me->query("neili") < 20)
      #         return notify_fail("你的内力不够。\n");
      # 
      #     q = (int)me->query("eff_qi") - (int)me->query("qi");
      #     if (q < 10)
      #         return notify_fail("你现在气力充沛。\n");
      #     n = 100 * q / me->query_skill("force");
      #         if (me->query("breakup"))
      #                 n = n * 7 / 10;
      #     if (n < 20)
      #         n = 20;
      #     if (me->query("special_skill/self"))
      #         n = n * 7 / 10;
      # 
      #     if ((int)me->query("neili") < n)
      #         {
      #         q = q * (int)me->query("neili") / n;
      #         n = (int)me->query("neili");
      #     }
      # 
      #     me->add("neili", -n);
      #     me->receive_heal("qi", q);
      # 
      #         message_vision("$N深深吸了几口气，脸色看起来好多了。\n", me);
      # 
      #         if (me->is_fighting() && ! me->query("special_skill/self"))
      #                 me->start_busy(1);
      # 
      #     return 1;
      # }
end

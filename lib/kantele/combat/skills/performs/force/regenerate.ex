defmodule Kantele.Combat.Skills.Performs.Force.Regenerate do
  @moduledoc """
  exert「regenerate」（source force/regenerate.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [{"lvl", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": [{"heal", "10"}, {"neili_cost", "20"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用内功恢复自己的精力。\n", "你现在精气旺盛。\n", "你的内力不够。\n"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "heal", "kind": "heal", "part": "jing", "source": None}], "resource_adds": [{"neili", "-neili_cost"}], "resource_queries": ["jing", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (me->is_fighting()) me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (me->is_fighting()) me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // regenerate.c
      # 
      # //inherit SSERVER;
      # 
      # int exert(object me, object target)
      # {
      #         int neili_cost;
      #         int lvl;
      #         int heal;
      # 
      #     if (target != me)
      #         return notify_fail("你只能用内功恢复自己的精力。\n");
      # 
      #     heal = (int)me->query("eff_jing") - (int)me->query("jing");
      #     if (heal < 10)
      #         return notify_fail("你现在精气旺盛。\n");
      # 
      #         lvl = me->query_skill("force");
      #         if (lvl <= 0) lvl = 1;
      #         neili_cost = heal * 60 / lvl;
      #         if (me->query("breakup"))
      #                 neili_cost = neili_cost * 7 / 10;
      #         if (neili_cost < 20) neili_cost = 20;
      #         if (neili_cost > me->query("neili"))
      #         {
      #                 neili_cost = me->query("neili");
      #                 heal = neili_cost * lvl / 60;
      #         }
      #         if (neili_cost < 20) neili_cost = 20;
      # 
      #     if ((int)me->query("neili") < neili_cost)
      #         return notify_fail("你的内力不够。\n");
      # 
      #     me->add("neili", -neili_cost);
      #     me->receive_heal("jing", heal);
      # 
      #         message_vision("$N深深吸了几口气，精神看起来好多了。\n", me);
      # 
      #         if (me->is_fighting()) me->start_busy(1);
      # 
      #     return 1;
      # }
end

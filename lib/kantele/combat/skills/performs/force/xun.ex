defmodule Kantele.Combat.Skills.Performs.Force.Xun do
  @moduledoc """
  exert「xun」（source force/xun.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所学的内功中没有这种功能。\n", "你所学的内功中没有这种功能。\n", "没有找到这个人物。\n", "这个人不知道在那里耶。\n"], "combat_messages": %{"fail": [], "other": [], "success": []}, "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": [], "remote_damage": false, "set_flags": [], "temp_set": []}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // xun.c
      # 
      # int exert(object me, object target)
      # {
      #         object where;
      # 
      #         if (! me->query("can_perform/wiz_test"))
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         if (! me->query("quest/id"))
      #                 return notify_fail("你所学的内功中没有这种功能。\n");
      # 
      #         target = find_player(me->query("quest/id"));
      # 
      #         if (! target)
      #                 target = find_living(me->query("quest/id"));
      # 
      #         if (! target)
      #                 target = find_object(me->query("quest/id"));
      # 
      #         if (! target)
      #                 return notify_fail("没有找到这个人物。\n");
      # 
      #         where = environment(target);
      # 
      #         if (! where)
      #                 return notify_fail("这个人不知道在那里耶。\n");
      # 
      #         if (target->query("place")
      #            && (target->query("place") == "西域"
      #            || target->query("place") == "很远的地方"))
      #                 target->move("/d/foshan/street3");
      # 
      #         write(sprintf("%s(%s)现在在%s(%s).\n",
      #                 (string)target->name(1),
      #                 (string)target->query("id"),
      #                 (string)where->short(),
      #                 (string)file_name(where)));
      #         
      #         return 1;
      # }
end

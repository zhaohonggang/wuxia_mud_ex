defmodule Kantele.Combat.Skills.Performs.XixingDafa.Sangong do
  @moduledoc """
  exert「sangong」（source xixing-dafa/sangong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你已经将内力散尽，没什么必要再散功了。\n"], "buff_delete": ["sucked"], "callback_functions": [%{"body": "me->delete_temp("sucked");", "name": "del_sucked", "params": "object me", "return_type": "void"}], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"max_neili", "-1"}], "resource_queries": ["max_neili"], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"max_neili", "-1"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // sangong.c
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int exert(object me, object target)
      # {
      #         if (me->query("max_neili") < 1)
      #                 return notify_fail("你已经将内力散尽，没什么必要再散功了。\n");
      # 
      #         tell_object(target, HIY "你默默的按照吸星大法的诀窍将内力散入奇经八脉。\n" NOR);
      #         message("vision", HIY + me->name() + "呼吸沉重，却又不像受伤的样"
      #                           "子，不知道在修炼什么厉害的功夫。\n" NOR,
      #                 environment(me), ({ me }));
      # 
      #         me->start_busy(1);
      #         me->add("max_neili", -1);
      # 
      #     return 1;
      # }
      # 
      # void del_sucked(object me)
      # {
      #         me->delete_temp("sucked");
      # }
end

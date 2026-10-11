defmodule Kantele.Combat.Skills.Performs.XixingDafa.Sangong do
  @moduledoc """
  exert「sangong」（source xixing-dafa/sangong.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  @impl true
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | max_neili: vitals.max_neili - 1}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"max_neili", "-1"}], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "resource_gates": [{"max_neili", "1"}]}

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

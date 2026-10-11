defmodule Kantele.Combat.Skills.Performs.Force.Xun do
  @moduledoc """
  exert「xun」（source force/xun.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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

  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"remote_damage": false}

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

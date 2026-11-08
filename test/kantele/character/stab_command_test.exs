defmodule Kantele.Character.StabCommandTest do
  @moduledoc """
  `stab` 命令 LPC 行为测试（cmds/std/stab.c）。

  纯函数 harness，物品/房间通过 `InteractionFixtures` 注入。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.Commands
  alias Kantele.Character.StabCommand
  alias Kantele.Character.InteractionFixtures, as: F

  defmodule TestStab do
    def run(conn, _params), do: %{conn | private: Map.put(conn.private, :stabbed, true)}
  end

  defp sword_instance, do: F.instance(id: "inst-1", item: F.item(id: "item:changjian", name: "长剑"))

  defp run(arg, player_opts \\ [], conn_opts \\ []) do
    p = F.player(player_opts)
    conn = F.build(p, conn_opts)
    StabCommand.run(conn, %{"rest" => arg})
  end

  describe "参数与背包门控" do
    test "无参数提示" do
      conn = run("")
      assert F.output_text(conn) == "你要用什么物品？\n"
    end

    test "背包里没有则提示" do
      # 默认 inventory 为空
      conn = run("长剑")
      assert F.output_text(conn) == "你身上没有这样东西。\n"
    end

    test "背包里有物品但无 handler 时走 LPC 兜底文案" do
      conn =
        run("长剑",
          inventory: [sword_instance()],
          items: %{"item:changjian" => F.item(id: "item:changjian", name: "长剑")}
        )

      assert F.output_text(conn) == "你翻来复去的弄了一会儿，也没能折腾好长剑。\n"
    end
  end

  describe "物品自定义 do_stab 分发" do
    test "注册了 do_stab handler 则调用" do
      conn =
        run("长剑",
          [inventory: [sword_instance()], items: %{"item:changjian" => F.item(id: "item:changjian", name: "长剑")}],
          [handlers: %{"do_stab" => {TestStab, :run}}]
        )

      assert Map.get(conn.private, :stabbed) == true
    end
  end

  describe "命令路由" do
    test "bare stab 命中且 rest 为空" do
      {:ok, parsed} = Commands.parse("stab")
      assert parsed.module == StabCommand
      assert Map.get(parsed.params, "rest", "") == ""
    end

    test "stab <物品> 透传整段文字为 rest" do
      {:ok, parsed} = Commands.parse("stab 长剑")
      assert parsed.module == StabCommand
      assert Map.get(parsed.params, "rest") == "长剑"
    end
  end
end

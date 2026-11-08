defmodule Kantele.Character.TouchCommandTest do
  @moduledoc """
  `touch` 命令 LPC 行为测试（cmds/std/touch.c）。

  纯函数 harness，物品/房间/NPC 通过 `InteractionFixtures` 注入。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.Commands
  alias Kantele.Character.TouchCommand
  alias Kantele.Character.InteractionFixtures, as: F

  defmodule TestTouch do
    def run(conn, _params), do: %{conn | private: Map.put(conn.private, :touched, true)}
  end

  defp sword_instance, do: F.instance(id: "inst-1", item: F.item(id: "item:changjian", name: "长剑"))

  defp bell_instance, do: F.instance(id: "inst-2", item: F.item(id: "item:zhong", name: "铜钟"))

  defp run(arg, player_opts \\ [], conn_opts \\ []) do
    p = F.player(player_opts)
    conn = F.build(p, conn_opts)
    TouchCommand.run(conn, %{"rest" => arg})
  end

  describe "参数与双范围取物门控" do
    test "无参数提示" do
      conn = run("")
      assert F.output_text(conn) == "你要触摸什么物品？\n"
    end

    test "背包与房间都找不到则提示" do
      conn = run("长剑")
      assert F.output_text(conn) == "你身上没有这样东西，附近也没有。\n"
    end

    test "命中的是人物则提示别乱动" do
      conn = run("石碑", [], characters: [F.npc(name: "石碑")])
      assert F.output_text(conn) == "你别乱动石碑了。\n"
    end
  end

  describe "物品自定义 do_touch 分发" do
    test "背包里的物品走 LPC 兜底文案" do
      conn = run("长剑", inventory: [sword_instance()], items: %{"item:changjian" => F.item(id: "item:changjian", name: "长剑")})
      assert F.output_text(conn) == "你摸了一下长剑。\n"
    end

    test "房间地上的物品走 LPC 兜底文案" do
      conn = run("铜钟", [], room_items: [bell_instance()], items: %{"item:zhong" => F.item(id: "item:zhong", name: "铜钟")})
      assert F.output_text(conn) == "你摸了一下铜钟。\n"
    end

    test "注册了 do_touch handler 则调用" do
      conn =
        run("铜钟",
          [],
          room_items: [bell_instance()],
          items: %{"item:zhong" => F.item(id: "item:zhong", name: "铜钟")},
          handlers: %{"do_touch" => {TestTouch, :run}}
        )

      assert Map.get(conn.private, :touched) == true
    end
  end

  describe "命令路由" do
    test "bare touch 命中且 rest 为空" do
      {:ok, parsed} = Commands.parse("touch")
      assert parsed.module == TouchCommand
      assert Map.get(parsed.params, "rest", "") == ""
    end

    test "touch <物品> 透传整段文字为 rest" do
      {:ok, parsed} = Commands.parse("touch 石碑")
      assert parsed.module == TouchCommand
      assert Map.get(parsed.params, "rest") == "石碑"
    end
  end
end

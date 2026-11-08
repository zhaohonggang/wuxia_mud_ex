defmodule Kantele.Character.StopCommandTest do
  @moduledoc """
  `stop <野兽>` 对 LPC `cmds/std/stop.c` 的逐门回归。

  注意 LPC 这里**没有**驭兽术等级门，也不检查 `race` / `userp`：
  参数 → present → `query_temp("owner") == me` → `is_busy()` →
  `message_vision` → `remove_all_enemy(1)`。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.BeastFixtures, as: F
  alias Kantele.Character.BeastState
  alias Kantele.Character.Commands
  alias Kantele.Character.StopCommand

  setup do
    F.setup_beast_state()
    on_exit(fn -> BeastState.reset() end)
    :ok
  end

  defp run(p, params, opts \\ []), do: StopCommand.run(F.build(p, opts), params)
  defp text(conn), do: F.output_text(conn)

  describe "LPC 门控" do
    test "无参数 / 空白参数" do
      assert text(run(F.player(), %{})) =~ "你要让什么野兽停止咬人？"
      assert text(run(F.player(), %{"target" => "  "})) =~ "你要让什么野兽停止咬人？"
    end

    test "房间里找不到目标" do
      assert text(run(F.player(), %{"target" => "黄骠马"})) =~ "这里没有这个野兽吧？"
    end

    test "不是自己的（含无主）都不理你" do
      b = F.beast()
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~
               "你不是它的主人"

      F.set_state(b.id, %{owner_id: "player-2"})
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~
               "你不是它的主人"
    end

    test "野兽正在忙" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1", busy: 1})
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~ "正在忙乎"
    end
  end

  describe "成功分支" do
    test "remove_all_enemy(1) 只清敌人，不动 owner/leader" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1", leader_id: "player-1", enemies: ["enemy-1"]})

      # 无驭兽术等级也能 stop（LPC stop.c 没有 skill 门）
      conn = run(F.player(training: 0), %{"target" => "黄骠马"}, characters: [b])

      assert text(conn) =~ "不咬了"
      refute text(conn) =~ "暂未开放"

      state = BeastState.get(b.id)
      assert state.enemies == []
      assert state.owner_id == "player-1"
      assert state.leader_id == "player-1"
    end
  end

  describe "路由" do
    test "带参 stop 把目标交给 run/2" do
      assert {:ok, parsed} = Commands.parse("stop 老虎")
      assert parsed.module == StopCommand
      assert parsed.params["target"] == "老虎"
    end

    test "裸 stop 仍命中" do
      assert {:ok, parsed} = Commands.parse("stop")
      assert parsed.module == StopCommand
    end
  end
end

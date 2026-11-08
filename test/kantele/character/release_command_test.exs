defmodule Kantele.Character.ReleaseCommandTest do
  @moduledoc """
  `release` 对 LPC `cmds/std/release.c`（源文件名 `fang.c`）的回归。

  LPC 遍历 `all_inventory(environment(me))`，只 `delete_temp` owner 三键；
  `attitude` / `ridable` 是 `set()`，放生后保留；也不动玩家侧 `comedby`。
  一头都没放到时播报「想放生，可是啥可放的」。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.BeastFixtures, as: F
  alias Kantele.Character.BeastState
  alias Kantele.Character.Commands
  alias Kantele.Character.ReleaseCommand

  setup do
    F.setup_beast_state()
    on_exit(fn -> BeastState.reset() end)
    :ok
  end

  defp run(p, opts \\ []), do: ReleaseCommand.run(F.build(p, opts), %{})
  defp text(conn), do: F.output_text(conn)

  describe "空放生" do
    test "房间里没有任何野兽" do
      conn = run(F.player())
      assert text(conn) =~ "想放生，可是没啥可放的"
      refute text(conn) =~ "暂未开放"
    end

    test "只有别人驯服的野兽" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-2"})
      conn = run(F.player(), characters: [b])
      assert text(conn) =~ "没啥可放的"
      assert BeastState.get(b.id).owner_id == "player-2"
    end

    test "已驯服但不在本房间的野兽不播报" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1"})
      assert text(run(F.player())) =~ "没啥可放的"
    end
  end

  describe "放生成功" do
    test "逐条播报，只清 owner 三键，attitude/ridable 保留" do
      horse = F.beast()
      snake = F.beast(id: "test:dushe", name: "毒蛇")

      F.set_state(horse.id, %{
        owner_id: "player-1",
        owner_name: "张三",
        leader_id: "player-1",
        attitude: "peace",
        ridable: true
      })

      F.set_state(snake.id, %{owner_id: "player-1", owner_name: "张三"})

      conn = run(F.player(), characters: [horse, snake])

      assert text(conn) =~ "很慈悲地把黄骠马放离"
      assert text(conn) =~ "很慈悲地把毒蛇放离"
      refute text(conn) =~ "没啥可放的"

      for id <- [horse.id, snake.id] do
        state = BeastState.get(id)
        assert state.owner_id == nil
        assert state.owner_name == nil
        assert state.leader_id == nil
      end

      assert BeastState.get(horse.id).attitude == "peace"
      assert BeastState.get(horse.id).ridable == true
    end

    test "不动玩家侧 comedby（LPC release.c 没有 delete_temp(\"comedby\")）" do
      horse = F.beast()
      F.set_state(horse.id, %{owner_id: "player-1"})
      p = F.player(temp: %{"comedby" => horse.id})

      conn = run(p, characters: [horse])
      assert F.comedby(conn) == horse.id
    end
  end

  describe "路由" do
    test "裸 release 命中 ReleaseCommand" do
      assert {:ok, parsed} = Commands.parse("release")
      assert parsed.module == ReleaseCommand
    end
  end
end

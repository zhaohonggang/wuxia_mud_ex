defmodule Kantele.Character.ReloadCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.ReloadCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  describe "reload 命令" do
    test "reload 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("reload")
      assert parsed.module == Kantele.Character.ReloadCommand
      assert parsed.function == :reload
    end

    test "recompile 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("recompile")
      assert parsed.module == Kantele.Character.ReloadCommand
      assert parsed.function == :recompile
    end

    test "recompile 返回结果不崩溃" do
      conn = ReloadCommand.recompile(build_conn(player()), %{})
      assert conn.output != []
    end
  end
end
defmodule Kantele.Character.BurningCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BurningCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      neili: Keyword.get(opts, :neili, 9000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{"force" => 350})
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        damage: Keyword.get(opts, :damage, %{}),
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  describe "路由解析" do
    test "burning 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("burning")
      assert parsed.module == BurningCommand
    end

    test "fenu 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("fenu")
      assert parsed.module == BurningCommand
    end
  end

  describe "burning 命令" do
    test "愤怒值不足时拒绝" do
      p = player(damage: %{craze: 500})
      conn = BurningCommand.run(build_conn(p), %{})
      assert conn.output != []
    end

    test "正常燃烧" do
      p = player(damage: %{craze: 2000})
      conn = BurningCommand.run(build_conn(p), %{})
      assert conn.output != []
    end
  end
end

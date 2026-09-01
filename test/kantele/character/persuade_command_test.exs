defmodule Kantele.Character.PersuadeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PersuadeCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20)
    }

    family = Keyword.get(opts, :family, %{"family_name" => "峨嵋派"})

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        family: family
      }
    }
  end

  describe "路由解析" do
    test "persuade 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("persuade")
      assert parsed.module == PersuadeCommand
    end

    test "quanjia 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("quanjia")
      assert parsed.module == PersuadeCommand
    end
  end

  describe "persuade 命令" do
    test "峨嵋派可以劝说" do
      p = player(family: %{"family_name" => "峨嵋派"})
      conn = PersuadeCommand.run(build_conn(p), %{"arg" => "某人 stop"})
      assert conn.output != []
    end

    test "非峨嵋派不能劝说" do
      p = player(family: %{"family_name" => "少林派"})
      conn = PersuadeCommand.run(build_conn(p), %{"arg" => "某人 stop"})
      assert conn.output != []
    end
  end
end

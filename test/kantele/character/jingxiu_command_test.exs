defmodule Kantele.Character.JingxiuCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.JingxiuCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{"buddhism" => 250})
    }

    family = Keyword.get(opts, :family, %{"family_name" => "少林派"})

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        family: family,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "jingxiu 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("jingxiu")
      assert parsed.module == JingxiuCommand
    end

    test "jingxiu 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("jingxiu")
      assert parsed.module == JingxiuCommand
    end
  end

  describe "jingxiu 命令" do
    test "战斗中拒绝" do
      combat = %{Combat.new() | enemies: ["enemy-1"]}
      p = player(combat: combat)
      conn = JingxiuCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "战斗"
    end

    test "精神不济时拒绝" do
      p = player(jing: 20)
      conn = JingxiuCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "精神"
    end

    test "佛学不够时拒绝" do
      p = player(skills: %{"buddhism" => 100})
      conn = JingxiuCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "佛学"
    end

    test "正常静修" do
      p = player(jing: 2000, skills: %{"buddhism" => 250})
      conn = JingxiuCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "心得"
    end
  end
end

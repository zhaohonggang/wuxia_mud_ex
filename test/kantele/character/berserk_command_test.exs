defmodule Kantele.Character.BerserkCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BerserkCommand
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
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 40),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 40),
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
    test "berserk 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("berserk")
      assert parsed.module == BerserkCommand
    end

    test "baofa 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("baofa")
      assert parsed.module == BerserkCommand
    end

    test "berserk 裸命令" do
      {:ok, parsed} = Kantele.Character.Commands.parse("berserk")
      assert parsed.module == BerserkCommand
    end
  end

  describe "berserk 命令" do
    test "内力不足时拒绝" do
      p = player(neili: 500)
      conn = BerserkCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "内力"
    end

    test "身体素质不够时拒绝" do
      p = player(neili: 9000, con: 20, str: 20)
      conn = BerserkCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "身体素质"
    end

    test "正常狂暴" do
      p = player(neili: 9000, con: 40, str: 30, qi: 5000)
      conn = BerserkCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "悍气"
    end
  end
end

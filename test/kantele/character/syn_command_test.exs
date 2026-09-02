defmodule Kantele.Character.SynCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.SynCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

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
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  describe "syn 命令" do
    test "无参数时提示" do
      p = player(neili: 10000, jingli: 2000, qi: 5000, max_neili: 10000, max_jingli: 2000, max_qi: 5000)
      conn = SynCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "与什么物品融合"
    end

    test "内力不足时拒绝" do
      p = player(neili: 1000, jingli: 2000, qi: 5000, max_neili: 10000, max_jingli: 2000, max_qi: 5000)
      conn = SynCommand.run(build_conn(p), %{"arg" => "剑"})
      assert output_text(conn) =~ "内力并不充沛"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("syn 剑")
      assert parsed.module == SynCommand
    end
  end
end

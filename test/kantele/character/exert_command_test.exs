defmodule Kantele.Character.ExertCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ExertCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 0),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000)
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: Keyword.get(opts, :skills, %{"force" => 50}),
      mapped: Keyword.get(opts, :mapped, %{"force" => "liuxi-neigong"}),
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
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

  describe "exert 命令" do
    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("exert powerup")
      assert parsed.module == ExertCommand
    end

    test "未知运功方法时报错" do
      p = player()
      conn = ExertCommand.run(build_conn(p), %{"function" => "unknown_func"})
      text = output_text(conn)
      assert text =~ "你不会这种运功方法"
    end

    test "无内功映射时报错" do
      p = player(mapped: %{})
      conn = ExertCommand.run(build_conn(p), %{"function" => "powerup"})
      text = output_text(conn)
      assert text =~ "你不会这种运功方法"
    end
  end
end

defmodule Kantele.Character.RespirateCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.RespirateCommand
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

  describe "respirate 命令" do
    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("respirate 50")
      assert parsed.module == RespirateCommand
    end

    test "无内功时拒绝" do
      p = player(skills: %{}, mapped: %{})
      conn = RespirateCommand.run(build_conn(p), %{"arg" => "50"})
      text = output_text(conn)
      assert text =~ "必须先用 enable"
    end

    test "精不足时拒绝" do
      p = player(jing: 5)
      conn = RespirateCommand.run(build_conn(p), %{"arg" => "50"})
      text = output_text(conn)
      assert text =~ "精不足"
    end

    test "数量太小时报错" do
      p = player()
      conn = RespirateCommand.run(build_conn(p), %{"arg" => "5"})
      text = output_text(conn)
      assert text =~ "至少 10 点精"
    end

    test "格式错误时报错" do
      p = player()
      conn = RespirateCommand.run(build_conn(p), %{"arg" => "abc"})
      text = output_text(conn)
      assert text =~ "格式"
    end

    test "气血不足70%时报错" do
      p = player(qi: 3000, max_qi: 5000)
      conn = RespirateCommand.run(build_conn(p), %{"arg" => "50"})
      text = output_text(conn)
      assert text =~ "身体状况太差"
    end

    test "条件满足时开始吐纳" do
      p = player()
      conn = RespirateCommand.run(build_conn(p), %{"arg" => "50"})
      text = output_text(conn)
      assert text =~ "开始吐纳"
    end
  end
end

defmodule Kantele.Character.ExerciseCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.ExerciseCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: Keyword.get(opts, :skills, %{"liuxi-neigong" => 100}),
      mapped: Keyword.get(opts, :mapped, %{}),
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
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

  describe "exercise 命令" do
    test "未启用内功时无法打坐" do
      p = player(mapped: %{})
      conn = ExerciseCommand.run(build_conn(p), %{"arg" => "10"})
      text = output_text(conn)

      assert text =~ "你必须先用 enable 选择"
    end

    test "格式错误提示" do
      p = player(mapped: %{"force" => "liuxi-neigong"})
      conn = ExerciseCommand.run(build_conn(p), %{"arg" => "abc"})
      text = output_text(conn)

      assert text =~ "格式：exercise"
    end

    test "耗气量少于10报错" do
      p = player(mapped: %{"force" => "liuxi-neigong"})
      conn = ExerciseCommand.run(build_conn(p), %{"arg" => "5"})
      text = output_text(conn)

      assert text =~ "至少耗费 10 点气"
    end

    test "气太少无法打坐" do
      p = player(mapped: %{"force" => "liuxi-neigong"}, qi: 5)
      conn = ExerciseCommand.run(build_conn(p), %{"arg" => "10"})
      text = output_text(conn)

      assert text =~ "你现在的气太少了"
    end

    test "exercise 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("exercise 20")
      assert parsed.module == ExerciseCommand
    end
  end
end
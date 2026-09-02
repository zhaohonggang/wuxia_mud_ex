defmodule Kantele.Character.JialiCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.JialiCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: Keyword.get(opts, :skills, %{"liuxi-neigong" => 100}),
      mapped: Keyword.get(opts, :mapped, %{"force" => "liuxi-neigong"}),
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

  describe "jiali 命令" do
    test "未启用内功时无法加力" do
      p = player(mapped: %{}, skills: %{})
      conn = JialiCommand.run(build_conn(p), %{"arg" => "10"})
      text = output_text(conn)

      assert text =~ "你还没用 enable 选择内功心法"
    end

    test "格式错误提示" do
      p = player()
      conn = JialiCommand.run(build_conn(p), %{"arg" => "abc"})
      text = output_text(conn)

      assert text =~ "格式：jiali"
    end

    test "关闭加力" do
      p = player()
      conn = JialiCommand.run(build_conn(p), %{"arg" => "0"})
      text = output_text(conn)

      assert text =~ "你收敛内息，不再加力"
    end

    test "加力超过上限报错" do
      p = player(skills: %{"liuxi-neigong" => 10})
      conn = JialiCommand.run(build_conn(p), %{"arg" => "10"})
      text = output_text(conn)

      assert text =~ "最多加力 5 档"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("jiali 5")
      assert parsed.module == JialiCommand
    end
  end
end
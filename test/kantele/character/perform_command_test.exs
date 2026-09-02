defmodule Kantele.Character.PerformCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PerformCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
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
      skills: %{},
      mapped: %{},
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

  describe "perform 命令" do
    test "格式错误提示" do
      p = player()
      conn = PerformCommand.run(build_conn(p), %{"action" => "liuxinjian"})
      text = output_text(conn)

      assert text =~ "用法：perform"
    end

    test "未使用的武功提示" do
      p = player()
      conn = PerformCommand.run(build_conn(p), %{"action" => "taiji-jian.liu"})
      text = output_text(conn)

      assert text =~ "你并没有使用这项武功"
    end

    test "perform 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("perform liuxin-jian.liu")
      assert parsed.module == PerformCommand
    end
  end
end
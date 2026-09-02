defmodule Kantele.Character.PracticeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.PracticeCommand
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

  describe "practice 命令" do
    test "未知武功提示" do
      p = player()
      conn = PracticeCommand.run(build_conn(p), %{"skill" => "not-a-skill"})
      text = output_text(conn)

      assert text =~ "没有这项武功"
    end

    test "practice 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("practice liuxin-jian")
      assert parsed.module == PracticeCommand
      assert parsed.params["skill"] == "liuxin-jian"
    end

    test "练 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("练 liuxin-jian")
      assert parsed.module == PracticeCommand
    end
  end
end
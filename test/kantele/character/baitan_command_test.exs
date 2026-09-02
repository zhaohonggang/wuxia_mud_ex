defmodule Kantele.Character.BaitanCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BaitanCommand
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

  describe "baitan 命令" do
    test "未摆摊时摆货提示" do
      p = player()
      conn = BaitanCommand.run(build_conn(p), %{"rest" => "stock 铁剑"})
      text = output_text(conn)

      assert text =~ "你还没有摆摊"
    end

    test "未摆摊时收货提示" do
      p = player()
      conn = BaitanCommand.run(build_conn(p), %{"rest" => "unstock 铁剑"})
      text = output_text(conn)

      assert text =~ "你还没有摆摊"
    end

    test "非法参数提示格式" do
      p = player()
      conn = BaitanCommand.run(build_conn(p), %{"rest" => "bogus"})
      text = output_text(conn)

      assert text =~ "指令格式："
    end

    test "baitan 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("baitan stock 铁剑")
      assert parsed.module == BaitanCommand
      assert parsed.params["rest"] == "stock 铁剑"
    end
  end
end
defmodule Kantele.Character.CookCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.CookCommand
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

  describe "cook 命令" do
    test "未激发菜艺提示" do
      p = player()
      conn = CookCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "请先激发你要使用的菜艺"
    end

    test "指定菜肴未激发菜艺提示" do
      p = player()
      conn = CookCommand.run(build_conn(p), %{"dish_name" => "回锅肉"})
      text = output_text(conn)

      assert text =~ "请先激发你要使用的菜艺"
    end

    test "cook 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("cook 回锅肉")
      assert parsed.module == CookCommand
      assert parsed.params["dish_name"] == "回锅肉"
    end
  end
end
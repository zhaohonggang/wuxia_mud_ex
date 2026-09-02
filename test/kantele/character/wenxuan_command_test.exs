defmodule Kantele.Character.WenxuanCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.WenxuanCommand

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

  describe "wenxuan 命令" do
    test "非法参数显示帮助" do
      p = player()
      conn = WenxuanCommand.run(build_conn(p), %{"arg" => "foo"})
      text = output_text(conn)

      assert text =~ "指令格式"
      assert text =~ "wenxuan"
    end

    test "添加文选功能待完善" do
      p = player()
      conn = WenxuanCommand.run(build_conn(p), %{"arg" => "add 5 from 留言板"})
      text = output_text(conn)

      assert text =~ "从留言板添加文选功能待完善"
    end

    test "删除文选需要巫师权限" do
      p = player()
      conn = WenxuanCommand.run(build_conn(p), %{"arg" => "del 2024 5"})
      text = output_text(conn)

      assert text =~ "删除文选功能需要巫师权限"
    end

    test "wenxuan 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("wenxuan 2024")
      assert parsed.module == WenxuanCommand
    end
  end
end
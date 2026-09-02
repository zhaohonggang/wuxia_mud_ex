defmodule Kantele.Character.YanlianCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.YanlianCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      qi: Keyword.get(opts, :qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20)
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

  defp player_busy do
    p = player()
    combat = %{p.meta.combat | busy: 3}
    %{p | meta: %{p.meta | combat: combat}}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "yanlian 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("yanlian")
      assert parsed.module == YanlianCommand
    end
  end

  describe "yanlian 命令" do
    test "无技能名时报错" do
      p = player()
      conn = YanlianCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "你想演练什么"
    end

    test "忙乱中拒绝" do
      p = player_busy()
      conn = YanlianCommand.run(build_conn(p), %{"arg" => "taiji"})
      text = output_text(conn)
      assert text =~ "正忙着"
    end

    test "有技能时报需要演练已有子技能的武功" do
      p = player()
      conn = YanlianCommand.run(build_conn(p), %{"arg" => "taiji"})
      text = output_text(conn)
      assert text =~ "已有子技能"
    end
  end
end

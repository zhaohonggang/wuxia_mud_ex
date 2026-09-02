defmodule Kantele.Character.CrattackCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.CrattackCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20)
    }

    damage = Keyword.get(opts, :damage, %{})

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        damage: damage,
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

  describe "路由解析" do
    test "crattack 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("crattack")
      assert parsed.module == CrattackCommand
    end
  end

  describe "crattack 命令" do
    test "愤怒值为0时报错" do
      p = player(damage: %{craze: 0})
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "心平气和"
    end

    test "愤怒值不足500时报错" do
      p = player(damage: %{craze: 300})
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "心平气和"
    end

    test "愤怒值不足1000时报错" do
      p = player(damage: %{craze: 800})
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "不够愤怒"
    end

    test "气血不足50%时报错" do
      p = player(damage: %{craze: 1500}, qi: 2000, max_qi: 5000)
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "体力太虚弱"
    end

    test "气血不足200时报错" do
      p = player(damage: %{craze: 1500}, qi: 300, max_qi: 500)
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "怒火中烧"
    end

    test "条件满足时成功施展" do
      p = player(damage: %{craze: 1500}, qi: 3000, max_qi: 5000)
      conn = CrattackCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "怒火中烧"
    end
  end
end

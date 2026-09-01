defmodule Kantele.Character.AccedeCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AccedeCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()
    temp = Keyword.get(opts, :temp, %{})

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        temp: temp
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

  describe "accede 命令" do
    test "无参数时提示格式" do
      conn = AccedeCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "格式"
    end

    test "无参数时提示格式 (空arg)" do
      conn = AccedeCommand.run(build_conn(player()), %{"arg" => ""})
      assert output_text(conn) =~ "应允谁的承诺"
    end

    test "没有待处理的求婚时拒绝" do
      p = player()
      conn = AccedeCommand.run(build_conn(p), %{"arg" => "真心"})
      assert output_text(conn) =~ "刚才没人向你求婚"
    end

    test "承诺不匹配时拒绝" do
      p = player(temp: %{"pending/engage_promise" => "真心", "pending/engage_from_name" => "李四"})
      conn = AccedeCommand.run(build_conn(p), %{"arg" => "假意"})
      assert output_text(conn) =~ "犹豫了半天"
      assert output_text(conn) =~ "承诺似乎对不上"
    end

    test "承诺匹配时发送事件" do
      p = player(temp: %{"pending/engage_promise" => "真心", "pending/engage_from_name" => "李四"})
      conn = AccedeCommand.run(build_conn(p), %{"arg" => "真心"})
      events = Enum.filter(conn.events, fn e -> e.topic == "engage/answer" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.target_name == "李四"
      assert event.data.promise == "真心"
    end
  end
end

defmodule Kantele.Character.SearchCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SearchCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(attrs \\ %{}) do
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
      attributes: attrs,
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

  defp search_events(conn) do
    Enum.filter(conn.events, fn event -> event.topic == "search/attempt" end)
  end

  describe "search 命令" do
    test "气不足时提示" do
      p = player()
      conn = SearchCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "你的气不足"
    end

    test "气足够时发出 search/attempt 事件" do
      p = player(%{"qi" => 40})
      conn = SearchCommand.run(build_conn(p), %{})
      events = search_events(conn)

      assert length(events) == 1
    end

    test "search 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("search")
      assert parsed.module == SearchCommand
    end
  end
end
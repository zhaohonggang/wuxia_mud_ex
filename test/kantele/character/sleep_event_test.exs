defmodule Kantele.Character.SleepEventTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SleepEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
    vitals = %Vitals{
      jing: 500,
      jingli: 2000,
      neili: 1000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 3000,
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
      id: "sleepy-1",
      name: "李四",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        temp: %{
          "sleeped" => true,
          "block_msg/all" => 1,
          "no_get" => 1,
          "no_get_from" => 1
        }
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

  defp player_meta(p), do: p.meta

  describe "sleep/wakeup 事件" do
    test "睡眠满冷却醒来完全恢复" do
      p = player()
      conn = SleepEvent.wakeup(build_conn(p), %{data: %{character_id: "sleepy-1"}})
      text = output_text(conn)

      assert text =~ "精力充沛"

      c = Kalevala.Character.Conn.character(conn)
      assert c.meta.vitals.qi == c.meta.vitals.max_qi
      assert c.meta.vitals.jing == c.meta.vitals.max_jing
      assert c.meta.vitals.neili == 8200
      assert c.meta.temp["sleeped"] != 1
      refute Map.has_key?(c.meta.temp, "sleeped")
    end

    test "非本人收到事件时不做处理" do
      p = player()
      conn = SleepEvent.wakeup(build_conn(p), %{data: %{character_id: "someone-else"}})

      assert conn.output == []
    end

    test "未在睡眠中直接返回" do
      p = %{player() | meta: %{player_meta(player()) | temp: %{}}}

      conn = SleepEvent.wakeup(build_conn(p), %{data: %{character_id: "sleepy-1"}})

      assert conn.output == []
    end

    test "冷却未满仅醒来不恢复" do
      p = %{
        player()
        | attributes: %{"last_sleep" => :os.system_time(:second)}
      }

      conn = SleepEvent.wakeup(build_conn(p), %{data: %{character_id: "sleepy-1"}})
      text = output_text(conn)

      assert text =~ "迷迷糊糊"

      c = Kalevala.Character.Conn.character(conn)
      assert c.meta.vitals.qi == 3000
      assert c.meta.temp["sleeped"] != true
    end
  end
end
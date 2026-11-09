defmodule Kantele.Character.BrothersEventTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.BrothersEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(brothers) do
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
      skills: %{}
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
        combat: Kantele.Character.Combat.new(),
        brothers: brothers
      }
    }
  end

  defp conn_with(brothers) do
    %Conn{character: player(brothers)}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "收到断义通知后从内存名单移除对方" do
    brothers = [%{id: "player-2", name: "李四"}, %{id: "player-3", name: "王五"}]
    conn = conn_with(brothers)

    new_conn = BrothersEvent.broken(conn, %{data: %{breaker_id: "player-2", breaker_name: "李四"}})

    assert output_text(new_conn) =~ "李四与你断绝了关系"
    updated = new_conn.private.update_character
    refute Enum.any?(updated.meta.brothers, &(&1.id == "player-2"))
    assert Enum.any?(updated.meta.brothers, &(&1.id == "player-3"))
  end

  test "对方本就不在名单时不报错" do
    conn = conn_with([])

    new_conn = BrothersEvent.broken(conn, %{data: %{breaker_id: "player-9", breaker_name: "赵六"}})

    assert new_conn.private.update_character.meta.brothers == []
  end
end

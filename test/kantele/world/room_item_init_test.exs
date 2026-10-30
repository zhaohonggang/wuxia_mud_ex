defmodule Kantele.World.RoomItemInitTest do
  @moduledoc """
  `Kantele.World.RoomItemInit`（房间内物品的 `init()`，首个移植：神龙岛草坪断肠花毒）。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.RoomItemInit

  @caoping "shenlong:caoping"

  defp player do
    %Kalevala.Character{
      id: "player:1",
      name: "张三",
      pid: self(),
      room_id: @caoping,
      inventory: [],
      meta: %PlayerMeta{
        vitals: %Vitals{jing: 300, qi: 500, max_jing: 300, max_qi: 500},
        stats: %Stats{str: 20, dex: 20, con: 20, int: 20, skills: %{}, mapped: %{}},
        combat: Kantele.Character.Combat.new(),
        temp: %{}
      }
    }
  end

  defp conn(character \\ player()), do: build_conn(character)

  defp present(true), do: fn _room_id, _keyword -> true end
  defp present(false), do: fn _room_id, _keyword -> false end

  defp conditions(conn), do: Map.get(conn.session || %{}, "conditions")

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn %Kalevala.Character.Conn.Text{data: data} -> data end)
    |> Enum.join()
  end

  test "草坪有断肠花：进入即中毒 30 点并提示" do
    conn = RoomItemInit.on_enter(conn(), @caoping, present(true))

    assert %{"flower_poison" => %{"duration" => 30}} = conditions(conn)
    assert output_text(conn) =~ "你只觉一股淡香袭来"
  end

  test "毒性累加：已有 10 点变 40 点" do
    conn = conn() |> Kalevala.Character.Conn.put_session("conditions", %{"flower_poison" => %{"duration" => 10}})

    conn = RoomItemInit.on_enter(conn, @caoping, present(true))

    assert %{"flower_poison" => %{"duration" => 40}} = conditions(conn)
  end

  test "草坪没有断肠花：不中毒、无提示" do
    conn = RoomItemInit.on_enter(conn(), @caoping, present(false))

    assert conditions(conn) == nil
    assert output_text(conn) == ""
  end

  test "其它房间不触发" do
    other = %{player() | room_id: "shenlong:kongdi"}

    conn = RoomItemInit.on_enter(conn(other), "shenlong:kongdi", present(true))

    assert conditions(conn) == nil
    assert output_text(conn) == ""
  end
end

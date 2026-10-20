defmodule Kantele.World.ItemDescHandlersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.ItemDescHandlers
  alias Kantele.World.ItemDescHandlers.GatedText
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua

  @config %{
    "kind" => "gated_text",
    "gate_temp" => "gua",
    "hidden" => "尘土已将其掩盖。",
    "shown" => "只见山壁上刻有三副巨图。"
  }

  test "item_desc_entry/2 distinguishes static and dynamic entries" do
    room = %Room{id: "z:r", item_desc: %{"wall" => "墙上写着字。", "bi" => @config}}

    assert Room.item_desc_entry(room, "wall") == {:static, "墙上写着字。"}
    assert Room.item_desc_entry(room, "bi") == {:dynamic, @config}
    assert Room.item_desc_entry(room, "nope") == nil
  end

  test "lookup/2 resolves the pilot handler and degrades safely" do
    assert ItemDescHandlers.lookup("hengyang:inzhushendong", "gated_text") ==
             {:ok, {GatedText, :run}}

    assert ItemDescHandlers.lookup("hengyang:inzhushendong", "missing") ==
             {:unimplemented, "missing"}
  end

  test "GatedText hides the text until the temp flag is set" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    hidden = GatedText.run(context, requester(%{}), %{config: @config})
    assert context_output(hidden) == "尘土已将其掩盖。\n"

    shown = GatedText.run(context, requester(%{"gua" => 1}), %{config: @config})
    assert context_output(shown) == "只见山壁上刻有三副巨图。\n"
  end

  test "Gua sets the gua temp flag on success" do
    conn = %Conn{character: %{meta: %PlayerMeta{combat: nil}}}

    conn = Gua.run(conn, %{trailing: "bi", room_id: "hengyang:inzhushendong"})

    assert conn_output(conn) ==
             "\n你走到山壁旁，将山壁上的尘土一一刮去，后面景象一一显露了出来。\n"

    assert conn.private.update_character.meta.temp["gua"] == 1
  end

  test "Gua rejects an unknown target without setting the flag" do
    conn = %Conn{character: %{meta: %PlayerMeta{combat: nil}}}

    conn = Gua.run(conn, %{trailing: "wall", room_id: "hengyang:inzhushendong"})

    assert conn_output(conn) == "你要刮什么？\n"
    assert conn.private.update_character == nil
  end

  defp requester(temp) do
    %{pid: self(), meta: %PlayerMeta{temp: temp}}
  end

  defp context_output(%{output: output}) do
    output
    |> Enum.map(fn {_pid, %{data: data}} -> data end)
    |> Enum.join()
  end

  defp conn_output(%Conn{output: output}) do
    output
    |> Enum.map(& &1.data)
    |> Enum.join()
  end
end

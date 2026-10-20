defmodule Kantele.World.ItemDescHandlersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.ItemDescHandlers
  alias Kantele.World.ItemDescHandlers.GatedText
  alias Kantele.World.ItemDescHandlers.ScoreTiers
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua

  @config %{
    "kind" => "gated_text",
    "gate_temp" => "gua",
    "hidden" => "尘土已将其掩盖。",
    "shown" => "只见山壁上刻有三副巨图。"
  }

  @jing_config %{
    "kind" => "score_tiers",
    "tiers" => [
      %{"min_score" => 0, "text" => "你看了半天，只看到自己的影子，没发现什么。"},
      %{"min_score" => 1000, "text" => "你觉得上面镌的经偈似乎有些不同。"},
      %{"min_score" => 5000, "text" => "你发现上面镌的经偈光泽和别处不一样，难道可以掀(xian)开？"}
    ]
  }

  @hua_config %{
    "kind" => "score_tiers",
    "tiers" => [
      %{"min_score" => 0, "text" => "这是一幅陈旧的画卷，没有什么不同。"},
      %{
        "min_score" => 3000,
        "text" => "这是一幅陈旧的画卷，画中一处微微隆起，你忍不住便想掀开看看。",
        "set_temp" => "marks/画1"
      }
    ]
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

  test "lookup/2 resolves the score-gated rooms" do
    assert ItemDescHandlers.lookup("shaolin:putiyuan", "score_tiers") ==
             {:ok, {ScoreTiers, :run}}

    assert ItemDescHandlers.lookup("beijing:aofu_shufang", "score_tiers") ==
             {:ok, {ScoreTiers, :run}}
  end

  test "ScoreTiers selects the highest tier at or below the score" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    assert run_score(context, 0, @jing_config) ==
             "你看了半天，只看到自己的影子，没发现什么。\n"

    assert run_score(context, 1000, @jing_config) ==
             "你觉得上面镌的经偈似乎有些不同。\n"

    assert run_score(context, 4999, @jing_config) ==
             "你觉得上面镌的经偈似乎有些不同。\n"

    assert run_score(context, 5000, @jing_config) ==
             "你发现上面镌的经偈光泽和别处不一样，难道可以掀(xian)开？\n"
  end

  test "ScoreTiers sends set_temp only on the tier that declares it" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    low = ScoreTiers.run(context, requester_with_score(2999), %{config: @hua_config})
    assert low.events == []

    high = ScoreTiers.run(context, requester_with_score(3000), %{config: @hua_config})

    assert [
             {pid, %{topic: "character/effects", data: %{effects: [{:set_temp, "marks/画1", 1}]}}}
           ] = high.events

    assert pid == self()
  end

  test "ScoreTiers falls back safely without tiers" do
    context = %Kalevala.World.Room.Context{data: %Room{}}
    assert run_score(context, 9999, %{}) == "这里没有这个东西。\n"
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

  defp requester_with_score(score) do
    %{pid: self(), meta: %PlayerMeta{stats: %Stats{score: score}}}
  end

  defp run_score(context, score, config) do
    context
    |> ScoreTiers.run(requester_with_score(score), %{config: config})
    |> context_output()
  end

  defp context_output(%{output: output}) do
    Enum.map_join(output, fn {_pid, %{data: data}} -> data end)
  end

  defp conn_output(%Conn{output: output}) do
    Enum.map_join(output, & &1.data)
  end
end

defmodule Kantele.World.ItemDescHandlersTest.FakeRoom do
  use GenServer

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: {:global, {Kalevala.World.Room, room_id}})
  end

  @impl true
  def init(room_id) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.ItemDescHandlersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.World.ItemDescHandlersTest.FakeRoom
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.ItemDescHandlers
  alias Kantele.World.ItemDescHandlers.GatedText
  alias Kantele.World.ItemDescHandlers.RoomOccupancyText
  alias Kantele.World.ItemDescHandlers.RoomTempText
  alias Kantele.World.ItemDescHandlers.ScoreTiers
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Hengyang.Furong1.Pull
  alias Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua
  alias Kantele.World.RoomActions.Hengyang.Zigaihole.Move

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

  test "lookup/2 resolves the room-state handlers" do
    assert ItemDescHandlers.lookup("hengyang:furong1", "room_temp") ==
             {:ok, {RoomTempText, :run}}

    assert ItemDescHandlers.lookup("hengyang:zigaihole", "room_temp") ==
             {:ok, {RoomTempText, :run}}

    assert ItemDescHandlers.lookup("guanwai:jingxiu", "room_occupancy") ==
             {:ok, {RoomOccupancyText, :run}}
  end

  test "RoomTempText switches on room temp state" do
    target_room = "test:room_temp"
    looker_room = "test:looker_temp"
    start_supervised!({FakeRoom, target_room})
    context = %Kalevala.World.Room.Context{data: %Room{id: looker_room}}

    config = %{
      "kind" => "room_temp",
      "room_id" => target_room,
      "key" => "marks/拉",
      "hidden" => "蜘蛛网完好。",
      "shown" => "蜘蛛网已被拉破。"
    }

    hidden = RoomTempText.run(context, requester(%{}), %{config: config, room_id: looker_room})
    assert context_output(hidden) == "蜘蛛网完好。\n"

    assert :ok = Room.put_state_by_id(target_room, "marks/拉", 1)

    shown = RoomTempText.run(context, requester(%{}), %{config: config, room_id: looker_room})
    assert context_output(shown) == "蜘蛛网已被拉破。\n"
  end

  test "RoomTempText reads the current room from context without a process call" do
    room_id = "test:current_room"

    context = %Kalevala.World.Room.Context{
      data: %Room{id: room_id, state: %{"marks/拉" => 1}}
    }

    config = %{
      "kind" => "room_temp",
      "key" => "marks/拉",
      "hidden" => "蜘蛛网完好。",
      "shown" => "蜘蛛网已被拉破。"
    }

    shown = RoomTempText.run(context, requester(%{}), %{config: config, room_id: room_id})
    assert context_output(shown) == "蜘蛛网已被拉破。\n"
  end

  test "RoomOccupancyText reads the target room snapshot" do
    target_room = "test:occupancy"
    looker_room = "test:jingxiu"
    pid = start_supervised!({FakeRoom, target_room})
    context = %Kalevala.World.Room.Context{data: %Room{id: looker_room}}

    config = %{
      "kind" => "room_occupancy",
      "room_id" => target_room,
      "hidden" => "门上挂了个牌子：休息室",
      "shown" => "门上挂了个牌子：休息中、请毋打扰"
    }

    empty =
      RoomOccupancyText.run(context, requester(%{}), %{config: config, room_id: looker_room})

    assert context_output(empty) == "门上挂了个牌子：休息室\n"

    :sys.replace_state(pid, fn state ->
      put_in(state.private.characters, [self()])
    end)

    busy = RoomOccupancyText.run(context, requester(%{}), %{config: config, room_id: looker_room})
    assert context_output(busy) == "门上挂了个牌子：休息中、请毋打扰\n"
  end

  test "RoomOccupancyText uses context.characters for the current room" do
    room_id = "test:current_occupancy"
    context = %Kalevala.World.Room.Context{data: %Room{id: room_id}, characters: [self()]}

    config = %{
      "kind" => "room_occupancy",
      "hidden" => "门上挂了个牌子：休息室",
      "shown" => "门上挂了个牌子：休息中、请毋打扰"
    }

    busy = RoomOccupancyText.run(context, requester(%{}), %{config: config, room_id: room_id})
    assert context_output(busy) == "门上挂了个牌子：休息中、请毋打扰\n"
  end

  test "Pull sets the room temp and reports state" do
    room_id = "test:furong1"
    start_supervised!({FakeRoom, room_id})

    opened = Pull.run(%Conn{}, %{trailing: "net", room_id: room_id})
    assert conn_output(opened) == "\n你把蜘蛛网拉了下来。\n"
    assert Room.get_state_by_id(room_id, "marks/拉") == 1

    again = Pull.run(%Conn{}, %{trailing: "net", room_id: room_id})
    assert conn_output(again) == "蜘蛛网已经被拉破了。\n"

    invalid = Pull.run(%Conn{}, %{trailing: "wall", room_id: room_id})
    assert conn_output(invalid) == "你要拉什么？\n"
  end

  test "Zigaihole Move toggles the room temp" do
    room_id = "test:zigaihole"
    start_supervised!({FakeRoom, room_id})

    opened = Move.run(%Conn{}, %{trailing: "desk", room_id: room_id})
    assert conn_output(opened) == "\n你用力一推，石桌下面竟露出一个坑(keng)来。\n\n"
    assert Room.get_state_by_id(room_id, "marks/移") == 1

    closed = Move.run(%Conn{}, %{trailing: "石桌", room_id: room_id})
    assert conn_output(closed) == "\n你用力一推，将石桌移回了原处。\n\n"
    assert Room.get_state_by_id(room_id, "marks/移") == nil

    invalid = Move.run(%Conn{}, %{trailing: "bed", room_id: room_id})
    assert conn_output(invalid) == "你想移什么？\n"
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

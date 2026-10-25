defmodule Kantele.World.RoomLookEventTest do
  @moduledoc """
  `Room.LookEvent` 的**运行期房述覆盖**回归（P5-6 批新增的 `set("long", ...)` 消费端）

  这里固化一个真实打到线上的 bug：

      LookEvent 曾无条件把 `Room.long_description/1` 的返回值写进 `room.description`，
      而该函数在**没有** `"long"` 房态时返回 `nil`（这是绝大多数房间的情况）
      → `LookView` 把 nil 混进文本列表
      → `Kalevala.Output.Tags.parse_string(nil, ...)` FunctionClauseError
      → websocket 连接进程直接退出（玩家一 look 就掉线）。

  **为什么 4653/0 的全量回归没抓住**：`Room.LookEvent` 此前**零测试覆盖**，
  而 `room_actions_break_test.exs` 对 `long_description/1` 的单测只断言了
  「无 long 时返回 nil」——正好把坏契约锁死了。本文件同时覆盖**调用点**与
  **崩溃点**（真的把渲染结果喂给 `Kalevala.Output.Tags`）。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Event
  alias Kalevala.World.Room.Context
  alias Kantele.World.Loader
  alias Kantele.World.Room.LookEvent

  @room_id "beijing:kangfu_men"

  setup_all do
    world = Loader.load()

    # ZoneCache 真实运行时由 Kickoff 填充；LookEvent 的 mini_map 要靠它取小地图
    Enum.each(world.zones, fn
      %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
      _ -> :skip
    end)

    room = Enum.find(world.rooms, &(&1.id == @room_id))
    %{room: room, static_description: room.description}
  end

  defp look_event(room, state) do
    room = %{room | state: state}

    event = %Event{
      from_pid: self(),
      acting_character: %{id: "player:test", name: "测试", pid: self()},
      topic: "room/look",
      data: %{}
    }

    context = %Context{
      data: room,
      characters: [],
      item_instances: []
    }

    LookEvent.call(context, event)
  end

  defp texts(context) do
    Enum.flat_map(context.output, fn
      {_pid, %{text: %{data: data}}} -> List.wrap(data)
      {_pid, %{data: data}} -> List.wrap(data)
      {_pid, %{text: text}} -> List.wrap(text)
    end)
  end

  defp flat_strings(data) do
    data
    |> List.wrap()
    |> Enum.flat_map(fn
      string when is_binary(string) -> [string]
      list when is_list(list) -> flat_strings(list)
      _other -> []
    end)
  end

  describe "look with no runtime \"long\" override (the normal case)" do
    test "keeps the static description and never emits nil", %{room: room, static_description: desc} do
      context = look_event(room, %{})

      strings = context |> texts() |> flat_strings()

      assert strings != []
      refute Enum.any?(strings, &is_nil/1)
      assert Enum.any?(strings, &String.contains?(&1, desc))
    end

    test "the rendered text survives Kalevala.Output.Tags (the real crash site)", %{room: room} do
      context = look_event(room, %{})

      assert Enum.all?(texts(context), fn data ->
               Kalevala.Output.process(data, Kalevala.Output.Tags) != :error
             end)
    end
  end

  describe "look with a runtime \"long\" override" do
    test "the long text replaces the static description", %{room: room, static_description: desc} do
      long = "桅杆已经断了，船底裂开一道大口子，海水正汩汩地灌进来。"

      context = look_event(room, %{"long" => long})

      strings = context |> texts() |> flat_strings()

      refute Enum.any?(strings, &is_nil/1)
      assert Enum.any?(strings, &String.contains?(&1, long))
      refute Enum.any?(strings, &String.contains?(&1, desc))
    end

    test "an empty-string \"long\" is not an override", %{room: room, static_description: desc} do
      context = look_event(room, %{"long" => ""})

      strings = context |> texts() |> flat_strings()

      refute Enum.any?(strings, &is_nil/1)
      assert Enum.any?(strings, &String.contains?(&1, desc))
    end
  end
end

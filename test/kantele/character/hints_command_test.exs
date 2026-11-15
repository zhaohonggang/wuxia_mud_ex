defmodule Kantele.Character.HintsCommandTest do
  @moduledoc """
  `hints` 命令链路回归：路由 → 事件 → 房间侧完整列表渲染。
  """
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Room.Context
  alias Kantele.Character.Commands
  alias Kantele.Character.HintsCommand
  alias Kantele.World.Room.HintsEvent

  defp player do
    %Kalevala.Character{
      id: "player:test",
      name: "测试",
      pid: self(),
      room_id: "test:room",
      meta: %{}
    }
  end

  defp hints_text(context) do
    Enum.find_value(context.output, fn
      {_pid, %{topic: "Room.Hints", text: %{data: data}}} -> IO.iodata_to_binary(data)
      _ -> false
    end)
  end

  test "hints / 交互 / 提示 三条裸命令都能命中" do
    Enum.each(["hints", "交互", "提示"], fn text ->
      assert {:ok, parsed} = Commands.parse(text), "#{text} 裸命令解析失败"
      assert parsed.module == HintsCommand
      assert parsed.params["command"] == text
    end)
  end

  test "run/2 发出 room/hints 事件并关掉本次 prompt" do
    conn = HintsCommand.run(build_conn(player()), %{})

    assert [%Event{topic: "room/hints"}] = conn.events
    assert conn.assigns[:prompt] == false
  end

  test "HintsEvent 输出完整列表（不做 6 组截断）" do
    room = %{id: "test:room", item_desc: %{"pen" => "花盆"}, actions: %{}}

    npcs =
      Enum.map(1..8, fn i ->
        %{id: "npc:#{i}", name: "NPC#{i}", meta: %{}}
      end)

    context = %Context{data: room, characters: npcs, item_instances: []}

    event = %Event{
      from_pid: self(),
      acting_character: %{id: "player:test", name: "测试"},
      topic: "room/hints",
      data: %{}
    }

    text = HintsEvent.call(context, event) |> hints_text()

    assert is_binary(text)
    assert text =~ "当前房间可交互命令"
    assert text =~ "look pen"
    Enum.each(1..8, fn i -> assert text =~ "NPC#{i}" end)
    assert String.contains?(text, "\n"), "提示应逐行换行，不是一坨文本"
  end

  test "房间没有任何特殊交互时给出明确回执，而非空白" do
    context = %Context{
      data: %{id: "test:room", item_desc: %{}, actions: %{}},
      characters: [],
      item_instances: []
    }

    event = %Event{
      from_pid: self(),
      acting_character: %{id: "player:test", name: "测试"},
      topic: "room/hints",
      data: %{}
    }

    result = HintsEvent.call(context, event)

    assert Enum.any?(result.output, fn
             {_pid, %{data: data}} when is_binary(data) -> String.contains?(data, "没有可列出")
             {_pid, %{text: %{data: data}}} ->
               String.contains?(IO.iodata_to_binary(data), "没有可列出")

             _ ->
               false
           end)
  end
end

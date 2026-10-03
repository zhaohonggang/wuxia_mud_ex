defmodule Kantele.RoomChannelPublishTest do
  @moduledoc """
  房间频道的发布准入判定

  `RoomChannel.publish_request/4` 原来无条件读 `options[:character].room_id`。
  但系统广播（`Kantele.Communication.announce/2`）是
  `publish(channel, event, [])` —— options 为空、`character` 是
  `system_character()` 返回的**裸 map**（没有 room_id 字段），
  于是 `nil.room_id()` 抛 UndefinedFunctionError，
  把房间频道进程连同调用方（玩家进程）一起带崩。

  线上触发路径：八卦阵「震」方向 -> TrapEvent -> Feature.Damage.unconcious
  -> handle_unconcious -> announce -> Communication.announce -> 这里。

  这组测试钉住「无发起者时放行、有发起者时按房间判定」。
  """
  use ExUnit.Case, async: true

  alias Kalevala.Event
  alias Kantele.RoomChannel

  @config [room_id: "shaolin:bagua5"]

  defp message_event do
    %Event{
      acting_character: nil,
      from_pid: self(),
      topic: Event.Message,
      data: %Event.Message{
        channel_name: "rooms:shaolin:bagua5",
        character: %{id: "", name: "系统", description: ""},
        id: Event.Message.generate_id(),
        text: "grant晕倒了。",
        type: "announcement"
      }
    }
  end

  describe "系统广播（options 里没有 character）" do
    test "announce 传的就是空 options，这里必须放行而不是崩" do
      assert RoomChannel.publish_request("rooms:shaolin:bagua5", message_event(), [], @config) ==
               :ok
    end

    test "拿到的是 system_character()（裸 map，没有 room_id）" do
      sys = Kantele.Communication.system_character()

      assert is_map(sys)
      refute Map.has_key?(sys, :room_id),
             "system_character 是裸 map，没有 room_id —— 这就是之前会崩的原因"
    end

    test "config 为空时也放行（不该炸）" do
      assert RoomChannel.publish_request("rooms:x", message_event(), [], []) == :ok
    end
  end

  describe "玩家自己发消息时仍按房间判定" do
    test "在本房间 -> 放行" do
      character = %Kalevala.Character{room_id: "shaolin:bagua5"}
      assert RoomChannel.publish_request("rooms:shaolin:bagua5", message_event(), [character: character], @config) == :ok
    end

    test "不在本房间 -> {:error, :not_in_room}（这条语义不能被上面的改动放宽）" do
      character = %Kalevala.Character{room_id: "shaolin:bagua0"}

      assert RoomChannel.publish_request("rooms:shaolin:bagua5", message_event(), [character: character], @config) ==
               {:error, :not_in_room}
    end
  end
end
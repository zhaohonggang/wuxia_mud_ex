defmodule Kantele.Character.ChannelEventTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.ChannelEvent
  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.Event.Message

  @vitals %{qi: 88, max_qi: 150, jing: 66, max_jing: 120, neili: 44, max_neili: 200}

  # 回归背景：系统公告的虚拟角色没有 meta，ChannelEvent 曾把它 assign 进
  # conn.assigns 后又用空 assigns 渲染 prompt，导致 prompt 模板
  # `%{vitals: vitals} = character.meta` 崩溃、foreman 重启踢回登录界面
  defp player() do
    %{
      id: "player:1",
      name: "grant",
      brain: nil,
      inventory: [],
      room_id: "sammatti:town_square",
      meta: %{vitals: @vitals}
    }
  end

  defp player_conn() do
    %Conn{character: player()}
  end

  defp message_event(type, character) do
    %Event{
      acting_character: nil,
      from_pid: self(),
      topic: Message,
      data: %Message{
        channel_name: "general",
        character: character,
        id: Message.generate_id(),
        text: "世界数据解析失败（data/world/liuxi.ucl），本次加载已放弃",
        type: type
      }
    }
  end

  test "系统公告后 prompt 用接收者的 vitals 渲染（不再崩溃）" do
    event = message_event("announcement", Kantele.Communication.system_character())

    conn = ChannelEvent.echo(player_conn(), event)

    assert %Conn.EventText{topic: "Character.Prompt", data: data} = List.last(conn.output)
    assert data == @vitals
  end

  test "普通频道消息同理（此前 prompt 误用发言者的 vitals）" do
    speaker = %{
      id: "npc:1",
      name: "报讯人",
      description: "",
      brain: nil,
      inventory: [],
      room_id: "sammatti:town_square",
      meta: %{vitals: %{qi: 1, max_qi: 2, jing: 3, max_jing: 4, neili: 5, max_neili: 6}}
    }

    conn = ChannelEvent.echo(player_conn(), message_event("speech", speaker))

    assert %Conn.EventText{topic: "Character.Prompt", data: data} = List.last(conn.output)
    assert data == @vitals
  end
end

defmodule Kantele.Character.TellEventTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.TellEvent
  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.Event.Message

  defp player_conn() do
    %Conn{
      character: %Kalevala.Character{
        id: "player-1",
        name: "张三",
        pid: self(),
        room_id: "test:room",
        inventory: [],
        meta: %PlayerMeta{
          vitals: Kantele.Character.Vitals.new(),
          stats: Kantele.Character.Stats.new(),
          combat: Kantele.Character.Combat.new()
        }
      }
    }
  end

  defp message_event(character) do
    %Event{
      acting_character: nil,
      from_pid: self(),
      topic: Message,
      data: %Message{
        channel_name: "characters:player-2",
        character: character,
        id: Message.generate_id(),
        text: "在吗？",
        type: "speech"
      }
    }
  end

  test "收到 tell 时把 meta.reply_to 记为发话人（reply 命令用）" do
    sender = %Kalevala.Character{
      id: "player-2",
      name: "李四",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }

    conn = TellEvent.echo(player_conn(), message_event(sender))

    assert Kalevala.Character.Conn.character(conn).meta.reply_to == "李四"
  end
end
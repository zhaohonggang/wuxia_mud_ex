defmodule Kantele.Character.CombatEventChatTest do
  @moduledoc """
  NPC 战斗闲聊（#144）：忠实移植 LPC inherit/char/npc.c#chat 的战斗分支。

  心跳（combat/tick）进入战斗且未忙乱时，按 NonPlayerMeta.chat_chance_combat 概率
  从 chat_msg_combat 随机挑一句，以普通说话发到房间频道（与 ChatAction 同款渲染）。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Communication

  @room_id "test:combat-chat-room-#{System.unique_integer([:positive])}"
  @enemy_room "other:room"

  setup_all do
    :ok = Communication.register("rooms:#{@room_id}", Kantele.RoomChannel, room_id: @room_id)
    :ok
  end

  setup do
    :ok =
      Communication.subscribe("rooms:#{@room_id}",
        character: %Kalevala.Character{id: "chat-sub", room_id: @room_id}
      )

    on_exit(fn ->
      Communication.unsubscribe("rooms:#{@room_id}",
        character: %Kalevala.Character{id: "chat-sub", room_id: @room_id}
      )
    end)

    :ok
  end

  defp enemy do
    # 异房敌人：tick 时落入 gone 分支，不触发 strike（避免额外心跳调度/噪声）
    %{id: "enemy:1", pid: self(), name: "对手", room_id: @enemy_room}
  end

  defp npc(overrides \\ []) do
    chat_msg_combat = Keyword.get(overrides, :chat_msg_combat, ["杀呀！某句战斗台词！"])
    chat_chance_combat = Keyword.get(overrides, :chat_chance_combat, 100)
    busy = Keyword.get(overrides, :busy, 0)
    enemies = Keyword.get(overrides, :enemies, [enemy()])

    meta =
      %NonPlayerMeta{
        zone_id: "test",
        vitals: Vitals.new(),
        stats: Stats.new(),
        chat_msg_combat: chat_msg_combat,
        chat_chance_combat: chat_chance_combat,
        combat: %Combat{enemies: enemies, busy: busy}
      }

    %Kalevala.Character{
      id: "npc:chat",
      name: "战斗 NPC",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: meta
    }
  end

  defp tick(npc), do: CombatEvent.tick(build_conn(npc), %Event{from_pid: self(), topic: "combat/tick", data: %{}})

  test "战斗中 NPC 按 chat_chance_combat 概率说 chat_msg_combat" do
    tick(npc())
    assert_receive {:room_message, text}
    assert text =~ "某句战斗台词"
  end

  test "玩家（PlayerMeta）战斗中不触发闲聊" do
    player =
      %Kalevala.Character{
        id: "player:1",
        name: "张三",
        pid: self(),
        room_id: @room_id,
        inventory: [],
        meta: %PlayerMeta{
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: %Combat{enemies: [enemy()]}
        }
      }

    CombatEvent.tick(build_conn(player), %Event{from_pid: self(), topic: "combat/tick", data: %{}})
    refute_receive {:room_message, _}, 100
  end

  test "chat_chance_combat = 0 的 NPC 不说" do
    tick(npc(chat_chance_combat: 0))
    refute_receive {:room_message, _}, 100
  end

  test "chat_msg_combat 为空的 NPC 不说" do
    tick(npc(chat_msg_combat: []))
    refute_receive {:room_message, _}, 100
  end

  test "忙乱（busy > 0）的 NPC 不说（本 tick 递减后仍忙）" do
    # busy=2 经 tick 内 decrement_busy 变为 1，仍 is_busy → 不说
    tick(npc(busy: 2))
    refute_receive {:room_message, _}, 100
  end

  test "无敌人（未战斗）的 NPC 不说" do
    tick(npc(enemies: []))
    refute_receive {:room_message, _}, 100
  end
end

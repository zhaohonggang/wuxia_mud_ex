defmodule Kantele.Character.AskCommandTest do
  @moduledoc """
  `ask` 指令测试：验证 `ask 地藏王 转世` 能否通过 `AskHandler` 分发到
  `Kantele.NPC.Dizangwang` 并触发 `Reborn.trigger`。
  """
  use ExVenture.DataCase, async: false
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.AskCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(attrs \\ []) do
    stats =
      Stats.new()
      |> Map.put(:combat_exp, Keyword.get(attrs, :combat_exp, 800_000_000))

    %Character{
      id: "ask-test-player",
      name: "ask-test-player",
      pid: self(),
      room_id: "register:yanluodian",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        coins: 100,
        setup_done: true,
        env: Map.merge(
          %{
            HellZhenPass: true,
            DiZangPass: true,
            SkyPass: true,
            gender: "男性",
            startroom: "city:kedian",
            registered: true
          },
          Keyword.get(attrs, :env, %{})
        )
      }
    }
  end

  defp dizangwang_npc do
    %{
      id: "dizangwang",
      name: "地藏王",
      pid: self(),
      # P4-B 的生死斗分支会走 NpcAttack.ref/1，要求快照含 :room_id
      room_id: "register:yanluodian",
      meta: %{
        aliases: ["dizang wang", "dizang", "wang"],
        ask_handler: "Kantele.NPC.Dizangwang"
      }
    }
  end

  defp ordinary_npc do
    %{
      id: "zhang_sanfeng",
      name: "张三丰",
      meta: %{
        aliases: ["zhang sanfeng", "zhang"],
        ask_handler: nil
      }
    }
  end

  defp conn_with_npc(player, npc) do
    conn = build_conn(player)
    private = %{conn.private | room: %{private: %{characters: [npc]}}}
    %{conn | private: private}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  test "ask 地藏王 转世：四前置齐备且已取丹(SkyPass) → 催交精元丹，不转世" do
    player = player()
    npc = dizangwang_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "地藏王", "keyword" => "转世"})

    # P4-B：ask 层不再直接转世；已取丹则催交精元丹
    refute updated_char(result).meta.character == "国士无双"

    text = output_text(result)
    assert String.contains?(text, "精元丹")
  end

  test "ask 地藏王 转世：未过十八层地狱(HellZhenPass) → check 拒绝" do
    # player() 默认 HellZhenPass: true，须显式覆盖为 false 才能真正缺该项
    player = player(env: %{HellZhenPass: false, DiZangPass: true, SkyPass: true})
    npc = dizangwang_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "地藏王", "keyword" => "转世"})

    text = output_text(result)
    assert String.contains?(text, "十八层地狱")
    refute updated_char(result).meta.character == "国士无双"
  end

  test "ask 地藏王 转世：过地狱+大宗师 但未取丹 → 发起生死斗，不转世" do
    player = player(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: false})
    npc = dizangwang_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "地藏王", "keyword" => "转世"})

    # P4-B 分支③：发起生死斗，双方各收 combat/start (type kill)
    assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}
    assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}

    # ask 层不直接转世
    refute updated_char(result).meta.character == "国士无双"
  end

  test "ask 无 ask_handler 的 NPC：落回事件流，不直接转世" do
    player = player()
    npc = ordinary_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "张三丰", "keyword" => "鹤嘴劲"})

    # 未配置 ask_handler → 发 event，不修改角色
    updated = updated_char(result)
    refute updated.meta.character == "国士无双"

    # 应该有一个 characters/ask 事件
    assert Enum.any?(result.events, &(&1.topic == "characters/ask"))
  end

  test "ask 不存在的 NPC：提示没有这样的人" do
    player = player()
    conn = build_conn(player)

    result = AskCommand.run(conn, %{"name" => "不存在的人", "keyword" => "转世"})

    text = output_text(result)
    assert String.contains?(text, "这里没有这样的人")
  end
end

defmodule Kantele.Character.AskCommandTest do
  @moduledoc """
  `ask` 指令测试：验证 `ask 地藏王 转世` 能否通过 `AskHandler` 分发到
  `Kantele.NPC.Dizangwang` 并触发 `Reborn.trigger`。
  """
  use ExVenture.DataCase, async: false
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
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

  test "ask 地藏王 转世：四前置齐备，触发转世，角色变国士无双" do
    player = player()
    npc = dizangwang_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "地藏王", "keyword" => "转世"})

    updated = updated_char(result)
    assert updated.meta.character == "国士无双"
    assert updated.meta.stats.combat_exp == 0
    assert updated.meta.env[:reborn][:count] == 1
    assert result.output != []
  end

  test "ask 地藏王 转世：缺大宗师前置 → 拒绝并说明缺项" do
    player = player(combat_exp: 100)
    npc = dizangwang_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "地藏王", "keyword" => "转世"})

    updated = updated_char(result)
    refute updated.meta.character == "国士无双"

    text = output_text(result)
    assert String.contains?(text, "大宗师")
  end

  test "ask 地藏王 转世：缺十八层地狱前置 → 拒绝" do
    # 明确置 HellZhenPass 为 false（player() 默认会带 HellZhenPass: true，须覆盖掉才能真正缺该项）
    player = player(env: %{HellZhenPass: false, DiZangPass: true, SkyPass: true})
    npc = dizangwang_npc()
    conn = conn_with_npc(player, npc)

    result = AskCommand.run(conn, %{"name" => "地藏王", "keyword" => "转世"})

    text = output_text(result)
    assert String.contains?(text, "十八层地狱")
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

defmodule Kantele.Character.HuntCommandTest do
  @moduledoc """
  `hunt` 指令测试：验证狩猎命令对 quarry NPC 的命中判定与 combat/attack 事件分发。
  """
  use ExVenture.DataCase, async: false
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.HuntCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(attrs \\ []) do
    stats =
      Stats.new()
      |> Map.put(:combat_exp, Keyword.get(attrs, :combat_exp, 50_000))

    %Character{
      id: "hunt-test-player",
      name: "hunt-test-player",
      pid: self(),
      room_id: "village:sexit",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        setup_done: true
      }
    }
  end

  # quarry_tu：power = 5，item1 = turou
  defp quarry_tu do
    %{
      id: "village:quarry_tu",
      name: "野兔",
      room_id: "village:sexit",
      meta: %{
        aliases: ["quarry_tu", "ye tu", "ye", "tu"],
        power: 5,
        item1: "clone_lib:turou"
      }
    }
  end

  # quarry_laohu：power = 40，玩家等级不足
  defp quarry_laohu do
    %{
      id: "village:quarry_laohu",
      name: "老虎",
      room_id: "village:sexit",
      meta: %{
        aliases: ["quarry_laohu", "lao hu", "lao", "hu"],
        power: 40,
        item1: "clone_lib:hupi",
        item2: "clone_lib:hurou"
      }
    }
  end

  # 非 quarry NPC：power 缺省为 0
  defp ordinary_npc do
    %{
      id: "village:smith",
      name: "铁匠",
      room_id: "village:sexit",
      meta: %{
        aliases: ["smith"],
        power: 0
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

  test "hunt 野兔：玩家等级 >= power → 发 combat/attack (type=hunt)" do
    player = player(combat_exp: 50_000)
    npc = quarry_tu()
    conn = conn_with_npc(player, npc)

    result = HuntCommand.run(conn, %{"target" => "野兔"})

    assert Enum.any?(result.events, fn
      %Event{topic: "combat/attack", data: %{type: "hunt", name: "野兔"}} -> true
      _ -> false
    end)

    text = output_text(result)
    assert String.contains?(text, "发起狩猎")
  end

  test "hunt 野兔：使用 id 别名 tu 也能命中" do
    player = player(combat_exp: 50_000)
    npc = quarry_tu()
    conn = conn_with_npc(player, npc)

    result = HuntCommand.run(conn, %{"target" => "tu"})

    assert Enum.any?(result.events, fn
      %Event{topic: "combat/attack", data: %{type: "hunt"}} -> true
      _ -> false
    end)
  end

  test "hunt 老虎：玩家等级 < power → 拒绝，提示太强" do
    player = player(combat_exp: 50_000) # level ~7，远低于 40
    npc = quarry_laohu()
    conn = conn_with_npc(player, npc)

    result = HuntCommand.run(conn, %{"target" => "老虎"})

    refute Enum.any?(result.events, fn
      %Event{topic: "combat/attack"} -> true
      _ -> false
    end)

    text = output_text(result)
    assert String.contains?(text, "太强了")
  end

  test "hunt 非 quarry NPC：提示不是可猎猎的野兽" do
    player = player(combat_exp: 50_000)
    npc = ordinary_npc()
    conn = conn_with_npc(player, npc)

    result = HuntCommand.run(conn, %{"target" => "铁匠"})

    text = output_text(result)
    assert String.contains?(text, "不是可猎猎的野兽")
  end

  test "hunt 无目标：显示用法" do
    player = player()
    conn = build_conn(player)

    result = HuntCommand.run(conn, %{"target" => ""})

    text = output_text(result)
    assert String.contains?(text, "指令格式")
  end

  test "hunt 正在战斗中：拒绝" do
    player = player(combat_exp: 50_000)
    npc = quarry_tu()
    conn = conn_with_npc(player, npc)

    fighting_player =
      %{
        player
        | meta: %{
          player.meta
          | combat: %Combat{enemies: [%{id: "enemy1"}]}
        }
      }
    conn = %{conn | character: fighting_player}

    result = HuntCommand.run(conn, %{"target" => "野兔"})

    text = output_text(result)
    assert String.contains?(text, "正在战斗中")
  end

  test "hunt 不存在的目标：提示没有这只野兽" do
    player = player(combat_exp: 50_000)
    npc = quarry_tu()
    conn = conn_with_npc(player, npc)

    result = HuntCommand.run(conn, %{"target" => "不存在的怪"})

    text = output_text(result)
    assert String.contains?(text, "这里没有这只野兽")
  end
end

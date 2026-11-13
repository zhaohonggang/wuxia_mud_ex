defmodule Kantele.Character.HorseCommandTest do
  @moduledoc """
  `horse` / `买马` / `buy_mount` 指令测试：验证马夫购买坐骑交互流程。
  """

  use ExVenture.DataCase, async: false
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.Character.HorseCommand
  alias Kantele.NPC.Horseboss

  defp player(attrs \\ []) do
    stats =
      Stats.new()
      |> Stats.set_skill("training", Keyword.get(attrs, :training, 30))

    %Character{
      id: "horse-test-player",
      name: "horse-test-player",
      pid: self(),
      room_id: "test:room",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        temp: %{},
        setup_done: true
      }
    }
  end

  defp horseboss_npc do
    %Character{
      id: "test:horseboss",
      name: "马夫",
      pid: self(),
      room_id: "test:room",
      attributes: %{},
      inventory: [],
      meta: %{
        kind: "horseboss",
        aliases: ["test:horseboss", "马夫"]
      }
    }
  end

  defp ordinary_npc do
    %Character{
      id: "test:smith",
      name: "铁匠",
      pid: self(),
      room_id: "test:room",
      attributes: %{},
      inventory: [],
      meta: %{
        aliases: ["smith", "铁匠"]
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

  test "horse <非马夫 NPC>：提示这人不是马夫" do
    player = player()
    npc = ordinary_npc()
    conn = conn_with_npc(player, npc)

    result = HorseCommand.run(conn, %{"name" => "铁匠", "rest" => nil})

    text = output_text(result)
    assert String.contains?(text, "不是马夫")
  end

  test "horse <马夫>：显示问候与物种列表（训练 >= 30）" do
    player = player(training: 30)
    npc = horseboss_npc()
    conn = conn_with_npc(player, npc)

    result = HorseCommand.run(conn, %{"name" => "马夫", "rest" => nil})

    text = output_text(result)
    assert String.contains?(text, "马夫笑道")
    assert String.contains?(text, "物种列表") or String.contains?(text, "马、")
  end

  test "horse <马夫>：训练不足时提示驯兽技艺不够" do
    player = player(training: 10)
    npc = horseboss_npc()
    conn = conn_with_npc(player, npc)

    result = HorseCommand.run(conn, %{"name" => "马夫", "rest" => nil})

    text = output_text(result)
    assert String.contains?(text, "驯兽技艺不够")
  end

  test "buy_mount <马夫>：英文别名与 horse 等效" do
    player = player(training: 30)
    npc = horseboss_npc()
    conn = conn_with_npc(player, npc)

    result = HorseCommand.run(conn, %{"name" => "马夫", "rest" => nil})

    text = output_text(result)
    assert String.contains?(text, "马夫笑道")
  end

  test "买马 <马夫>：中文别名也能显示问候" do
    player = player(training: 30)
    npc = horseboss_npc()
    conn = conn_with_npc(player, npc)

    result = HorseCommand.run(conn, %{"name" => "马夫", "rest" => nil})

    text = output_text(result)
    assert String.contains?(text, "马夫笑道")
  end

  test "Horseboss.is_horseboss?/1：kind 为 horseboss 返回 true" do
    npc = horseboss_npc()
    assert Horseboss.is_horseboss?(npc) == true
  end

  test "Horseboss.is_horseboss?/1：普通 NPC 返回 false" do
    assert Horseboss.is_horseboss?(ordinary_npc()) == false
  end
end

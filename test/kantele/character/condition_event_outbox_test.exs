defmodule Kantele.Character.ConditionEventOutboxTest do
  @moduledoc """
  `condition/tick` 的出站通道（daemon → 玩家）。

  daemon 是纯函数、拿不到 conn，所以 `Kantele.Character.ConditionEvent` 从
  `state` 上读两个键落地：

    - `state.condition_messages` — `[{:tell, text} | {:vision, text}]`
    - `state.condition_unconcious` — `true`

  首个使用者是 `Kantele.Drunk`。这里用**真实 tick 全链**验证（而不是只测
  `Drunk.do_effect/3` 的纯函数返回值），因为最容易静默失效的正是「daemon 写了
  消息、宿主没 flush」这一跳 —— 症状是玩家喝醉后毫无反应。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  # con=20 + max_neili=1000/50=20 -> limit=(20+20)*2=80
  # limit/2=40（扣精档）、limit/4=20（回精档）、>80（昏厥档）
  defp player() do
    vitals = %Vitals{
      jing: 100,
      jingli: 2000,
      neili: 9000,
      max_neili: 1000,
      max_jingli: 2000,
      qi: 100,
      max_qi: 200,
      max_jing: 200
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 0,
      score: 0,
      potential: 0,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp tick(conn) do
    ConditionEvent.tick(conn, %Event{from_pid: self(), topic: "condition/tick", data: %{}})
  end

  defp drunk_conn(duration) do
    build_conn(player(), %{"conditions" => %{"drunk" => %{"duration" => duration}}})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "condition/tick 出站通道" do
    test "limit/2 档：本人收到提示、扣精、醉度递减" do
      conn = tick(drunk_conn(50))

      assert output_text(conn) =~ "大概是醉了"
      # `{npc}` 只出现在房间广播里，不能漏进本人文本
      refute output_text(conn) =~ "{npc}"

      character = conn.private.update_character || conn.character
      assert character.meta.vitals.jing == 90
      assert character.meta.vitals.qi == 100

      # 生命周期先递减：50 -> 49
      assert conn.session["conditions"]["drunk"]["duration"] == 49
    end

    test "limit/4 档：回精回气" do
      conn = tick(drunk_conn(30))

      assert output_text(conn) =~ "眼皮有些沉重了"

      character = conn.private.update_character || conn.character
      assert character.meta.vitals.jing == 110
      assert character.meta.vitals.qi == 115
    end

    test "过量：昏厥（qi/jing 归零）+ 醉度归零待摘除" do
      conn = tick(drunk_conn(100))

      character = conn.private.update_character || conn.character
      assert character.meta.vitals.qi == 0
      assert character.meta.vitals.jing == 0

      assert conn.session["conditions"]["drunk"]["duration"] == 0
      assert output_text(conn) =~ "醉得不省人事"
    end

    test "醉度耗尽后条件被摘除，心跳停投" do
      conn = tick(drunk_conn(1))

      assert conn.session["conditions"] == nil
    end

    test "无条件时 tick 不崩、不产消息" do
      conn = tick(build_conn(player(), %{}))

      assert output_text(conn) == ""
      assert conn.session["conditions"] == nil
    end
  end
end

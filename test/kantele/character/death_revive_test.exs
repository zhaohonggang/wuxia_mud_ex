defmodule Kantele.Character.DeathReviveTest do
  @moduledoc """
  死亡→地府→还阳 完整链路测试（对齐 LPC feature/damage.c die + bai.c 白无常接引）。

  - 死亡落点 / 还阳落点配置（death:gate / city:wumiao）
  - 白无常 ask 还阳：幽灵态允许、非幽灵态拒绝
  - CombatEvent.revive：解除幽灵态、满状态、传送武庙、落点记 startroom
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Event
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.NPC.Wuchang
  alias Kantele.World

  defp player(opts \\ []) do
    vitals = %Vitals{
      qi: Keyword.get(opts, :qi, 1),
      max_qi: Keyword.get(opts, :max_qi, 5000),
      jing: Keyword.get(opts, :jing, 1),
      max_jing: Keyword.get(opts, :max_jing, 5000),
      neili: Keyword.get(opts, :neili, 100),
      max_neili: Keyword.get(opts, :max_neili, 100),
      jingli: Keyword.get(opts, :jingli, 0),
      max_jingli: Keyword.get(opts, :max_jingli, 0)
    }

    stats = %Stats{str: 20, dex: 20, con: 20, int: 20}

    %Character{
      id: Keyword.get(opts, :id, "ghost-1"),
      name: Keyword.get(opts, :name, "游魂"),
      pid: self(),
      room_id: Keyword.get(opts, :room_id, "death:gate"),
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new(),
        env: Keyword.get(opts, :env, %{ghost: true})
      }
    }
  end

  describe "死亡/还阳落点配置" do
    test "死坠鬼门关、还阳落武庙" do
      assert World.death_room_id() == "death:gate"
      assert World.revive_room_id() == "city:wumiao"
    end
  end

  describe "白无常 ask 还阳" do
    test "非幽灵态被拒绝" do
      asker = %Character{id: "p1", meta: %PlayerMeta{env: %{}}}
      assert {:error, _} = Wuchang.check(asker, nil, "还阳")
    end

    test "幽灵态允许，并投递 character/revive 事件" do
      asker = %Character{id: "p1", pid: self(), meta: %PlayerMeta{env: %{ghost: true}}}
      assert :ok = Wuchang.check(asker, nil, "还阳")
      assert :ok = Wuchang.execute(asker, nil, "还阳")
      assert_receive %Event{topic: "character/revive"}, 500
    end
  end

  describe "CombatEvent.revive 还阳处理" do
    test "解除幽灵态、满状态、传送武庙、落点记 startroom" do
      conn = build_conn(player())
      conn = CombatEvent.revive(conn, %Event{from_pid: self(), topic: "character/revive", data: %{}})

      char = conn.private.update_character || conn.character

      # 幽灵态解除（damage + env 两处同步）
      refute Map.get(char.meta.damage || %{}, :ghost)
      refute Map.get(char.meta.env, :ghost)

      # 满状态（恢复到自身上限，不重置上限）
      assert char.meta.vitals.qi == 5000
      assert char.meta.vitals.max_qi == 5000
      assert char.meta.vitals.jing == 5000

      # 传送武庙
      assert char.room_id == World.revive_room_id()

      # 落点记 startroom
      assert char.meta.env.startroom == World.revive_room_id()
    end
  end

  describe "白无常 death_stage 分段还阳（LPC bai.c death_stage/2）" do
    test "每段推进，第 6 段后自动还阳" do
      conn = build_conn(player())

      for stage <- 0..5 do
        event = %Event{from_pid: self(), topic: "character/death_stage", data: %{stage: stage}}
        conn = CombatEvent.death_stage(conn, event)

        char = conn.private.update_character || conn.character

        # 每段白无常都会说话，输出应有新增
        assert length(conn.output) >= 1

        if stage < 5 do
          # 非最后一段：ghost 还在，仍在鬼门关
          assert Map.get(char.meta.env, :ghost) == true
          assert char.room_id == World.death_room_id()
        else
          # 最后一段：已还阳（解除幽灵态、满状态、传武庙、记 startroom）
          refute Map.get(char.meta.env, :ghost)
          refute Map.get(char.meta.damage || %{}, :ghost)
          assert char.meta.vitals.qi == 5000
          assert char.meta.vitals.jing == 5000
          assert char.room_id == World.revive_room_id()
          assert char.meta.env.startroom == World.revive_room_id()
        end
      end
    end

    test "非幽灵态时 death_stage 中断，不做任何事" do
      living = %Character{
        id: "p-living",
        name: "活人",
        pid: self(),
        room_id: "death:gate",
        meta: %PlayerMeta{
          env: %{ghost: false},
          damage: %{},
          vitals: %Vitals{qi: 100, max_qi: 100, jing: 100, max_jing: 100}
        }
      }
      conn = build_conn(living)
      output_before = length(conn.output)

      event = %Event{from_pid: self(), topic: "character/death_stage", data: %{stage: 0}}
      conn = CombatEvent.death_stage(conn, event)

      char = conn.private.update_character || conn.character
      assert Map.get(char.meta.env, :ghost) == false
      assert char.room_id == "death:gate"
      # 没有台词发送，输出不应增加
      assert length(conn.output) == output_before
    end

    test "不在鬼门关时 death_stage 中断，不做任何事" do
      ghost_outside = %Character{
        id: "p-ghost-out",
        name: "游魂",
        pid: self(),
        room_id: "city:wumiao",
        meta: %PlayerMeta{
          env: %{ghost: true},
          damage: %{ghost: true},
          vitals: %Vitals{qi: 1, max_qi: 100, jing: 1, max_jing: 100}
        }
      }
      conn = build_conn(ghost_outside)
      output_before = length(conn.output)

      event = %Event{from_pid: self(), topic: "character/death_stage", data: %{stage: 0}}
      conn = CombatEvent.death_stage(conn, event)

      char = conn.private.update_character || conn.character
      assert Map.get(char.meta.env, :ghost) == true
      assert char.room_id == "city:wumiao"
      # 没有台词发送，输出不应增加
      assert length(conn.output) == output_before
    end
  end
end

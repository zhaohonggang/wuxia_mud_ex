defmodule Kantele.Character.ForgingTimeoutEventTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Event
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.ForgingTimeoutEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging

  @owner_id "player-to-1"
  @owner_name "钱七"

  setup do
    Forging.ensure_table()
    Forging.delete(@owner_id)
    :ok
  end

  defp npc(id, name) do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{})

    %Character{
      id: id,
      name: name,
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp moye, do: npc(Forging.moye_id(), "莫邪 Moye")
  defp ganjiang, do: npc(Forging.ganjiang_id(), "干将 Ganjiang")

  defp quote_session(extra \\ %{}) do
    %{
      status: "item_gived",
      value: 2_200_000,
      material_item_id: "forge:xuantie",
      material_instance_id: "inst-xuantie",
      owner_id: @owner_id,
      owner_name: @owner_name,
      player_pid: self(),
      types: nil
    }
    |> Map.merge(extra)
  end

  defp waiting_session(extra \\ %{}) do
    %{
      status: "inputing",
      can_help: false,
      waited: 4,
      ctype: "剑",
      unit: "柄",
      point: 100,
      material_item_id: "forge:xuantie",
      material_instance_id: "inst-xuantie",
      making_instance_id: "inst-xuantie",
      owner_id: @owner_id,
      owner_name: @owner_name,
      player_pid: self()
    }
    |> Map.merge(extra)
  end

  defp material, do: %Instance{id: "inst-xuantie", item_id: "forge:xuantie"}

  # 房间快照注入（生产走房间进程）
  defp conn_with_room(character, ids) do
    characters = Enum.map(ids, fn id -> %{id: id, pid: self()} end)
    conn = build_conn(character)
    %{conn | private: %{conn.private | room: %{characters: characters}}}
  end

  defp with_material(npc) do
    %{npc | inventory: [material() | npc.inventory]}
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  describe "quote_timeout（LPC moye.c time_out）" do
    test "玩家在场 → 退料 + 发 forge/refund + 清会话" do
      Forging.put(@owner_id, quote_session())
      token = Map.get(Forging.get(@owner_id), :timer_token)

      conn =
        ForgingTimeoutEvent.quote_timeout(
          conn_with_room(with_material(moye()), [@owner_id]),
          %Event{
            from_pid: self(),
            topic: "forge/quote_timeout",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      # 会话清空、材料从莫邪背包移除
      assert Forging.get(@owner_id) == nil
      refute Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))

      # 玩家收到退款事件
      assert_receive %Event{topic: "forge/refund", data: data}, 1_000
      assert data.material_instance.id == "inst-xuantie"
      assert data.message =~ "交还给了你"
    end

    test "玩家不在场 → 材料掉在房间地上（ItemDrop.Request）" do
      Forging.put(@owner_id, quote_session())
      token = Map.get(Forging.get(@owner_id), :timer_token)

      conn =
        ForgingTimeoutEvent.quote_timeout(
          conn_with_room(with_material(moye()), []),
          %Event{
            from_pid: self(),
            topic: "forge/quote_timeout",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      assert Forging.get(@owner_id) == nil

      drops =
        Enum.filter(conn.events, fn
          %Event{topic: Event.ItemDrop.Request} -> true
          _ -> false
        end)

      assert length(drops) == 1
      assert hd(drops).data.item_instance.id == "inst-xuantie"

      # 玩家不收到退款事件（人已经走了）
      refute_receive %Event{topic: "forge/refund"}, 100
    end

    test "已付款的会话超时 → 材料与定金一起退回" do
      money = %Instance{id: "inst-gold", item_id: "forge:gold"}
      Forging.put(@owner_id, quote_session(%{status: "answer_type", money_instance: money}))
      token = Map.get(Forging.get(@owner_id), :timer_token)

      _conn =
        ForgingTimeoutEvent.quote_timeout(
          conn_with_room(with_material(moye()), [@owner_id]),
          %Event{
            from_pid: self(),
            topic: "forge/quote_timeout",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      assert_receive %Event{topic: "forge/refund", data: data}, 1_000
      assert data.material_instance.id == "inst-xuantie"
      assert data.money_instance.id == "inst-gold"
    end

    test "令牌过期（已被 answer 取消）→ 什么都不做" do
      Forging.put(@owner_id, quote_session())

      conn =
        ForgingTimeoutEvent.quote_timeout(
          conn_with_room(with_material(moye()), [@owner_id]),
          %Event{
            from_pid: self(),
            topic: "forge/quote_timeout",
            data: %{owner_id: @owner_id, token: -1}
          }
        )

      # 会话还在、材料还在
      assert Forging.get(@owner_id).status == "item_gived"
      assert Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))
      refute_receive %Event{topic: "forge/refund"}, 100
    end
  end

  describe "waiting（LPC ganjiang.c waiting）" do
    test "还有次数且玩家在场 → 催prompt、waited 减一、重排 300 秒" do
      Forging.put(@owner_id, waiting_session())
      token = Map.get(Forging.get(@owner_id), :timer_token)

      conn =
        ForgingTimeoutEvent.waiting(
          conn_with_room(with_material(ganjiang()), [@owner_id]),
          %Event{
            from_pid: self(),
            topic: "forge/waiting",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      s = Forging.get(@owner_id)
      assert s.waited == 3
      assert s.status == "inputing"
      # 重排了下一跳
      assert_receive %Event{topic: "forge/waiting"}, 1_000
      # 材料没被销毁
      assert Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))
    end

    test "waited 归零 → 销毁半成品且不退款" do
      Forging.put(@owner_id, waiting_session(%{waited: 1}))
      token = Map.get(Forging.get(@owner_id), :timer_token)

      conn =
        ForgingTimeoutEvent.waiting(
          conn_with_room(with_material(ganjiang()), [@owner_id]),
          %Event{
            from_pid: self(),
            topic: "forge/waiting",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      assert Forging.get(@owner_id) == nil
      refute Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))
      # 不退款
      refute_receive %Event{topic: "forge/refund"}, 100
      # 也不再重排
      refute_receive %Event{topic: "forge/waiting"}, 100
    end

    test "玩家进程已消失 → 立即销毁" do
      dead = spawn(fn -> :ok end)
      ref = Process.monitor(dead)
      assert_receive {:DOWN, ^ref, :process, ^dead, _}, 1_000

      Forging.put(@owner_id, waiting_session(%{player_pid: dead}))
      token = Map.get(Forging.get(@owner_id), :timer_token)

      conn =
        ForgingTimeoutEvent.waiting(
          conn_with_room(with_material(ganjiang()), []),
          %Event{
            from_pid: self(),
            topic: "forge/waiting",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      assert Forging.get(@owner_id) == nil
      refute Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))
    end

    test "玩家还在但离开了房间 → 只提醒，不销毁" do
      Forging.put(@owner_id, waiting_session())
      token = Map.get(Forging.get(@owner_id), :timer_token)

      conn =
        ForgingTimeoutEvent.waiting(
          conn_with_room(with_material(ganjiang()), []),
          %Event{
            from_pid: self(),
            topic: "forge/waiting",
            data: %{owner_id: @owner_id, token: token}
          }
        )

      assert Forging.get(@owner_id).waited == 3
      assert Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))
    end
  end
end

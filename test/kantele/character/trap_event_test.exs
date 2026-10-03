defmodule Kantele.Character.TrapEventTest do
  @moduledoc """
  角色侧陷阱副作用的执行

  这组测试盯的是**上一版真实踩过的坑**：`{:force_move, room_id}` 原来只是
  `%{conn.character | room_id: room_id}`，也就是「改了状态」而不是「移动」——
  房间频道订阅还在旧房间、没发 leave/enter、客户端不重新 look，
  结果玩家看到「提示说掉进僧监、人还在原地」。

  所以这里不只断言 room_id 变了，还要断言真的走了移动流程
  （`Teleport.teleport/2` 会把 room/look 事件排进conn.private）。
  """
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.TrapEvent

  defp player_conn(room \\ "shaolin:wuxing0") do
    %Conn{
      character: %Kalevala.Character{
        id: "player-1",
        name: "张三",
        pid: self(),
        room_id: room,
        inventory: [],
        meta: %PlayerMeta{
          vitals: Kantele.Character.Vitals.new(),
          stats: Kantele.Character.Stats.new(),
          combat: Kantele.Character.Combat.new(),
          temp: %{}
        }
      }
    }
  end

  defp trap_event(effects) do
    %Event{
      acting_character: nil,
      from_pid: self(),
      topic: "trap/effect",
      data: %{effects: effects}
    }
  end

  # 走 Events 路由注册的同一个函数（topic "trap/effect" -> TrapEvent.run/2）
  defp run(conn, effects) do
    TrapEvent.run(conn, trap_event(effects))
  end

  # put_character/2 只暂存到 private.update_character，所以断言要读那个
  defp applied(conn), do: conn.private.update_character || conn.character

  # 结构体不实现 Access 协议，put_in/2 在 %Conn{} / %Kalevala.Character{} 上会抛
  # UndefinedFunctionError —— 必须显式重建（与 cc0eead 同一类坑）。
  defp with_temp(conn, temp) do
    meta = conn.character.meta
    %{conn | character: %{conn.character | meta: %{meta | temp: temp}}}
  end

  defp with_combat_exp(conn, value) do
    meta = conn.character.meta
    %{conn | character: %{conn.character | meta: %{meta | stats: %{meta.stats | combat_exp: value}}}}
  end

  describe "force_move：必须是真的移动" do
    test "room_id 确实变了" do
      conn = run(player_conn(), [{:force_move, "shaolin:jianyu1"}])
      assert applied(conn).room_id == "shaolin:jianyu1"
    end

    test "排进了 room/look 事件（否则客户端不会刷新房间显示）" do
      conn = run(player_conn(), [{:force_move, "shaolin:jianyu1"}])

      topics = queued_event_topics(conn)

      assert "room/look" in topics,
             "强制移动后应触发 room/look，否则玩家看到的还是原房间（实际排了 #{inspect(topics)}）"
    end

    test "发出了离/进两段 Movement 事件（对应 LPC move 的可见效果）" do
      conn = run(player_conn(), [{:force_move, "shaolin:jianyu1"}])

      data = queued_event_data(conn)

      # MoveView "leave" / "enter" 各一段（data 已经是 Movement 结构体本身）
      leave? =
        Enum.any?(data, &match?(%Kalevala.Event.Movement{direction: :from}, &1))

      enter? =
        Enum.any?(data, &match?(%Kalevala.Event.Movement{direction: :to}, &1))

      assert leave?, "应有 :from（离开原房间）事件"
      assert enter?, "应有 :to（进入目标房间）事件"
    end
  end

  describe "set_temp / delete_prefix" do
    test "set_temp 写入 temp" do
      conn = run(player_conn(), [{:set_temp, "wuxing/水", 3}])
      assert applied(conn).meta.temp["wuxing/水"] == 3
    end

    test "delete_prefix 删掉整棵子树，而不是单个键" do
      conn =
        player_conn()
        |> with_temp(%{
          "wuxing/金" => 2,
          "wuxing/水" => 2,
          "bagua/count" => 5
        })

      conn = run(conn, [{:delete_prefix, "wuxing/"}])

      # wuxing 下的两个键都没了，bagua 的留着
      assert applied(conn).meta.temp == %{"bagua/count" => 5}
    end

    test "delete_prefix 不会误删前缀相近的键" do
      conn =
        player_conn()
        |> with_temp(%{
          "wuxing/金" => 2,
          "wuxingx/金" => 9
        })

      conn = run(conn, [{:delete_prefix, "wuxing/"}])

      assert Map.has_key?(applied(conn).meta.temp, "wuxingx/金")
      refute Map.has_key?(applied(conn).meta.temp, "wuxing/金")
    end
  end

  describe "add" do
    test "neili 不会被扣成负数" do
      conn = player_conn()
      conn = run(conn, [{:add, :neili, -50}])
      assert applied(conn).meta.vitals.neili >= 0
    end

    test "combat_exp 会被扣" do
      conn =
        player_conn()
        |> with_combat_exp(1000)

      conn = run(conn, [{:add, :combat_exp, -50}])
      assert applied(conn).meta.stats.combat_exp == 950
    end
  end

  describe "未知副作用不应炸掉角色进程" do
    test "不认识的效果被记录并跳过" do
      conn = run(player_conn(), [{:totally_unknown_effect, 1}])
      assert applied(conn).room_id == "shaolin:wuxing0"
    end
  end


  describe "连续副作用不能互相覆盖" do
    # put_character/2 只暂存到 private.update_character。若每条副作用都读
    # conn.character（旧的），后一条就会把前面的成果覆盖掉 —— 五行迷宫脱困
    # 是 set_temp -> delete_prefix -> force_move 三步，少一步就出不来。
    test "三步全都在最终角色上生效" do
      conn =
        player_conn()
        |> with_temp(%{"wuxing/金" => 2, "wuxing/水" => 2, "wuxing/木" => 2,
                       "wuxing/火" => 2, "wuxing/土" => 2})
        |> run([
          {:set_temp, "wuxing/水", 3},
          {:delete_prefix, "wuxing/"},
          {:force_move, "shaolin:andao2"}
        ])

      character = applied(conn)

      # 传送生效
      assert character.room_id == "shaolin:andao2"

      # wuxing 整棵子树被清掉（delete_prefix 没被 force_move 覆盖掉）
      refute Map.has_key?(character.meta.temp, "wuxing/水")
      refute Map.has_key?(character.meta.temp, "wuxing/金")
    end

    test "set_temp 后接 delete_prefix：temp 被清空" do
      conn =
        player_conn()
        |> with_temp(%{"wuxing/金" => 1})
        |> run([{:set_temp, "wuxing/水", 1}, {:delete_prefix, "wuxing/"}])

      assert applied(conn).meta.temp == %{}
    end
  end

  # ---- helpers ----
  #
  # Kalevala 把待发事件排在 **conn.events**（不是 conn.private）：
  #   conn.move/6 和 conn.event/3 都是 `Map.put(conn, :events, conn.events ++ [event])`

  defp queued_event_topics(conn), do: Enum.map(conn.events, & &1.topic)

  defp queued_event_data(conn), do: Enum.map(conn.events, & &1.data)
end

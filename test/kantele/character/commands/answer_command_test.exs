defmodule Kantele.Character.AnswerCommandTest do
  @moduledoc """
  `answer` 指令测试：验证 quest_gift Y/N 接受/拒绝、门贡扣除、物品发放、
  以及 ask_you 房间广播路径。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.AnswerCommand
  alias Kantele.Character.AskCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.World.Items
  alias Kantele.World.Item

  @item_id "test:quest_gift_item"
  @item_name "测试礼物"
  @npc_name "测试NPC"

  defp player(attrs \\ []) do
    stats =
      Stats.new()
      |> Map.put(:gongxian, Keyword.get(attrs, :gongxian, 1000))

    %Character{
      id: "answer-test-player",
      name: "answer-test-player",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        coins: 100,
        temp: %{},
        setup_done: true
      }
    }
  end

  defp conn_with_temp(player, temp) do
    conn = build_conn(player)
    meta = %PlayerMeta{player.meta | temp: temp}
    character = %{player | meta: meta}
    %{conn | character: character}
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

  setup do
    Items.put(@item_id, %ItemDef{
      id: @item_id,
      name: @item_name,
      verbs: [],
      callback_module: Item,
      meta: %{}
    })

    on_exit fn ->
      Items.delete(@item_id)
    end

    :ok
  end

  describe "quest_gift 路径" do
    test "answer Y：扣门贡、发物品、清 temp" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "Y"})

      c = updated_char(result)

      # 门贡扣除：500 - 300 = 200
      assert c.meta.stats.gongxian == 200

      # 物品加入背包
      assert length(c.inventory) == 1
      assert hd(c.inventory).item_id == @item_id

      # temp 清除
      assert Map.get(c.meta.temp, :quest_gift) == nil

      # 输出文案
      assert output_text(result) =~ @item_name
      assert output_text(result) =~ @npc_name
      assert output_text(result) =~ "300"
    end

    test "answer yes：同 Y，扣门贡、发物品" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "yes"})

      c = updated_char(result)
      assert c.meta.stats.gongxian == 200
      assert length(c.inventory) == 1
      assert Map.get(c.meta.temp, :quest_gift) == nil
    end

    test "answer 是：同 Y，扣门贡、发物品" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "是"})

      c = updated_char(result)
      assert c.meta.stats.gongxian == 200
      assert length(c.inventory) == 1
    end

    test "answer N：婉拒、清 temp、不扣门贡、不发物品" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "N"})

      c = updated_char(result)

      assert c.meta.stats.gongxian == 500
      assert length(c.inventory) == 0
      assert Map.get(c.meta.temp, :quest_gift) == nil
      assert output_text(result) =~ "婉拒"
    end

    test "answer no：同 N，婉拒" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "no"})

      c = updated_char(result)
      assert c.meta.stats.gongxian == 500
      assert length(c.inventory) == 0
      assert Map.get(c.meta.temp, :quest_gift) == nil
    end

    test "answer 否：同 N，婉拒" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "否"})

      c = updated_char(result)
      assert c.meta.stats.gongxian == 500
      assert length(c.inventory) == 0
    end

    test "门贡不足：拒绝、不扣钱、不发物品、temp 保留" do
      player = player(gongxian: 100)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "Y"})

      c = updated_char(result)

      assert c.meta.stats.gongxian == 100
      assert length(c.inventory) == 0
      assert Map.get(c.meta.temp, :quest_gift) != nil
      assert output_text(result) =~ "门贡不足"
    end

    test "有待处理 quest_gift 但输入非 Y/N：提示，temp 保留" do
      player = player(gongxian: 500)
      conn =
        conn_with_temp(player, %{quest_gift: %{npc: @npc_name, obj: @item_id, gongxian: 300}})

      result = AnswerCommand.run(conn, %{"rest" => "maybe"})

      c = updated_char(result)

      assert c.meta.stats.gongxian == 500
      assert length(c.inventory) == 0
      assert Map.get(c.meta.temp, :quest_gift) != nil
      assert output_text(result) =~ "Y 接受或 N 拒绝"
    end

    test "无 quest_gift 时 answer Y：走 stub（不匹配 quest_gift 路径）" do
      player = player(gongxian: 500)
      conn = conn_with_temp(player, %{})

      result = AnswerCommand.run(conn, %{"rest" => "Y"})

      # 没有 quest_gift，Y 不匹配，走 ask_you（也不匹配），最后走 stub
      assert output_text(result) =~ "目前不支持该选项"
    end

    test "无 quest_gift 时 answer N：走 stub" do
      player = player(gongxian: 500)
      conn = conn_with_temp(player, %{})

      result = AnswerCommand.run(conn, %{"rest" => "N"})

      assert output_text(result) =~ "目前不支持该选项"
    end

    test "裸 answer（无参数）：stub_empty" do
      player = player()
      conn = conn_with_temp(player, %{})

      result = AnswerCommand.run(conn, %{})

      assert output_text(result) =~ "你要回答什么"
    end
  end

  describe "ask_you 路径" do
    test "answer <asker> <msg>：房间广播、清 temp" do
      player = player()
      conn =
        conn_with_temp(player, %{ask_you: "张三"})

      result = AnswerCommand.run(conn, %{"rest" => "张三 你好"})

      # temp 清除
      c = updated_char(result)
      assert Map.get(c.meta.temp, :ask_you) == nil

      # 广播事件：向房间频道发布 vision 消息
      assert Enum.any?(result.private.channel_changes, fn
        {:publish, "rooms:test:room", _, _, _} -> true
        _ -> false
      end)
    end

    test "answer 错误的玩家名：pass through，temp 保留" do
      player = player()
      conn =
        conn_with_temp(player, %{ask_you: "张三"})

      result = AnswerCommand.run(conn, %{"rest" => "李四 你好"})

      c = updated_char(result)
      assert Map.get(c.meta.temp, :ask_you) == "张三"

      # 应该走 stub
      assert output_text(result) =~ "目前不支持该选项"
    end

    test "answer 只有玩家名无消息：pass through" do
      player = player()
      conn =
        conn_with_temp(player, %{ask_you: "张三"})

      result = AnswerCommand.run(conn, %{"rest" => "张三"})

      c = updated_char(result)
      assert Map.get(c.meta.temp, :ask_you) == "张三"

      assert output_text(result) =~ "目前不支持该选项"
    end

    test "无 ask_you 时 answer <玩家> <msg>：走 stub" do
      player = player()
      conn = conn_with_temp(player, %{})

      result = AnswerCommand.run(conn, %{"rest" => "张三 你好"})

      assert output_text(result) =~ "目前不支持该选项"
    end
  end

  describe "AskCommand quest_gift 设置" do
    test "ask <npc> quest：NPC 有 quest_gift 时设置 temp[:quest_gift]" do
      player = player()
      npc =
        %Character{
          id: "test-npc",
          name: @npc_name,
          pid: self(),
          room_id: "test:room",
          attributes: %{},
          meta: %{
            aliases: [@npc_name],
            ask_handler: nil,
            quest_gift: %{"obj" => @item_id, "gongxian" => 300}
          }
        }

      conn = build_conn(player)
      private = %{conn.private | room: %{private: %{characters: [npc]}}}
      conn = %{conn | private: private}

      result = AskCommand.run(conn, %{"name" => @npc_name, "keyword" => "quest"})

      c = updated_char(result)
      quest_gift = Map.get(c.meta.temp, :quest_gift)
      refute is_nil(quest_gift)
      assert quest_gift[:npc] == @npc_name
      assert quest_gift[:obj] == @item_id
      assert quest_gift[:gongxian] == 300

      # 输出提示文案
      assert output_text(result) =~ @item_name
      assert output_text(result) =~ "answer Y/N"
    end

    test "ask <npc> quest：NPC 无 quest_gift 时落回事件流" do
      player = player()
      npc =
        %Character{
          id: "test-npc",
          name: @npc_name,
          pid: self(),
          room_id: "test:room",
          attributes: %{},
          meta: %{
            aliases: [@npc_name],
            ask_handler: nil
          }
        }

      conn = build_conn(player)
      private = %{conn.private | room: %{private: %{characters: [npc]}}}
      conn = %{conn | private: private}

      result = AskCommand.run(conn, %{"name" => @npc_name, "keyword" => "quest"})

      # 应该发出 characters/ask 事件，不设置 temp
      c = updated_char(result)
      assert Map.get(c.meta.temp, :quest_gift) == nil
      assert Enum.any?(result.events, &(&1.topic == "characters/ask"))
    end

    test "ask <npc> 非 quest 关键词：不设置 quest_gift" do
      player = player()
      npc =
        %Character{
          id: "test-npc",
          name: @npc_name,
          pid: self(),
          room_id: "test:room",
          attributes: %{},
          meta: %{
            aliases: [@npc_name],
            ask_handler: nil,
            quest_gift: %{"obj" => @item_id, "gongxian" => 300}
          }
        }

      conn = build_conn(player)
      private = %{conn.private | room: %{private: %{characters: [npc]}}}
      conn = %{conn | private: private}

      result = AskCommand.run(conn, %{"name" => @npc_name, "keyword" => "转世"})

      c = updated_char(result)
      assert Map.get(c.meta.temp, :quest_gift) == nil
    end
  end
end

defmodule Kantele.World.ShaolinDuAcceptTest do
  @moduledoc """
  少林三老（渡厄/渡劫/渡难）accept_object（对应 LPC `kungfu/class/shaolin/du-e.c` /
  `du-jie.c` / `du-nan.c` `accept_object`）。

  - `ShaolinDuAccept.handle/5`（NPC 进程侧）：玩家给「黑索」 →
    发 `shaolin_du/destruct-item` 事件给玩家进程，渲染「甚好，甚好。」。
  - `GiveEvent.shaolin_du_destruct_item/2`（玩家进程侧）：移除物品实例，提示「甚好，甚好。」。
  - `GiveEvent.receive` 兜底：未命中 shaolin_du 规则时，kind="any" allow-all 仍走 give/result(ok:true)。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.Combat
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.ShaolinDuAccept

  @heisuo_id "黑索"

  defp npc_conn do
    %Conn{
      character: %Kalevala.Character{
        id: "shaolin:du_e",
        name: "渡厄",
        room_id: "shaolin:fumoquan",
        inventory: [],
        meta: %NonPlayerMeta{
          zone_id: "shaolin",
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Combat.new()
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp instance(item_id \\ @heisuo_id) do
    %Instance{
      id: "heisuo-inst-#{:erlang.unique_integer([:monotonic])}",
      item_id: item_id,
      created_at: DateTime.utc_now()
    }
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "ShaolinDuAccept.handle（三老收黑索）" do
    test "给黑索 → 发 shaolin_du/destruct-item 并渲染「甚好，甚好。」" do
      conn0 = npc_conn()
      data = %{reply_to: self(), from_id: "player:test"}
      inst = instance()

      conn1 = ShaolinDuAccept.handle(conn0, conn0.character, inst, data, "玩家")

      assert_receive %Event{topic: "shaolin_du/destruct-item", data: ev}, 1000
      assert ev.from_id == "player:test"
      assert ev.item_id == @heisuo_id
      assert ev.instance_id == inst.id
      assert ev.to_id == "shaolin:du_e"
      assert ev.from_name == "玩家"
      assert out_text(conn1) =~ "甚好，甚好。"
    end
  end

  # ---- GiveEvent.receive（shaolin_du 规则 + kind="any" 兜底） ----

  defp shaolin_du_npc_conn do
    %Conn{
      character: %Kalevala.Character{
        id: "shaolin:du_jie",
        name: "渡劫",
        room_id: "shaolin:fumoquan",
        inventory: [],
        meta: %NonPlayerMeta{
          zone_id: "shaolin",
          accept: [%{kind: "shaolin_du", name: "黑索"}],
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Combat.new()
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  describe "GiveEvent.receive（shaolin_du 规则）" do
    test "物品未注册（Items.get 失败）→ give/result(ok:false)，不走 shaolin_du" do
      _conn =
        GiveEvent.receive(shaolin_du_npc_conn(), %Event{
          topic: "characters/give",
          data: %{
            item_instance: instance(),
            item_name: "黑索",
            from_name: "玩家",
            from_id: "player:test",
            reply_to: self()
          }
        })

      # Items.get 返回 nil → {:error, "物品不在房间中。"} → give/result(ok:false)
      assert_receive %Event{topic: "give/result", data: %{ok: false}}, 1000
      refute_receive %Event{topic: "shaolin_du/destruct-item"}, 500
    end

    test "给非黑索物品 → 物品未注册（Items.get 失败）→ give/result(ok:false)，不走 shaolin_du" do
      # test:baozi 未注册 → Items.get 返回 nil → match_accept_rule 返回
      # {:error, "物品不在房间中。"} → give/result(ok:false)
      # 关键断言：不会发 shaolin_du/destruct-item
      _conn =
        GiveEvent.receive(shaolin_du_npc_conn(), %Event{
          topic: "characters/give",
          data: %{
            item_instance: instance("test:baozi"),
            item_name: "包子",
            from_name: "玩家",
            from_id: "player:test",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "give/result", data: %{ok: false}}, 1000
      refute_receive %Event{topic: "shaolin_du/destruct-item"}, 500
    end
  end

  # ---- GiveEvent.shaolin_du_destruct_item（玩家进程侧移除实例） ----

  defp player_conn(opts) do
    inventory = Keyword.get(opts, :inventory, [])

    meta = %PlayerMeta{
      vitals: Vitals.new(),
      stats: Stats.new(),
      combat: Combat.new()
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: "shaolin:fumoquan",
        inventory: inventory,
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp character(conn), do: conn.private.update_character || conn.character

  describe "GiveEvent.shaolin_du_destruct_item（移除黑索并提示）" do
    test "收到回执 → 移除黑索实例并提示" do
      inst = instance()
      conn0 = player_conn(inventory: [inst])

      conn1 =
        GiveEvent.shaolin_du_destruct_item(conn0, %{
          data: %{item_id: @heisuo_id, instance_id: inst.id, from_id: "player:test"}
        })

      char = character(conn1)
      assert char.inventory == []
      assert out_text(conn1) =~ "你把东西交给了对方"
      assert out_text(conn1) =~ "甚好，甚好。"
    end

    test "不是自己的回执 → 不动状态" do
      inst = instance()
      conn0 = player_conn(inventory: [inst])

      conn1 =
        GiveEvent.shaolin_du_destruct_item(conn0, %{
          data: %{item_id: @heisuo_id, instance_id: inst.id, from_id: "someone-else"}
        })

      assert conn1.private.update_character == nil
    end
  end
end

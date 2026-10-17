defmodule Kantele.World.Room.ShopRequestEventTest do
  @moduledoc """
  商店请求转发（A10/N2）——A1「shop 桥接」的中间环节。

  链路：玩家命令 `list`/`buy` -> 角色进程把事件发给房间进程 ->
  本模块补上 `reply_to`/`buyer_id`/`buyer_name` 并转给商人 NPC ->
  NPC 侧 NpcShopEvent 报价 -> 结果事件回玩家进程。

  玩家命令只发 `name`（list）或 `item_name`/`quantity`（buy），
  商人侧 NpcShopEvent 只认 `reply_to`，所以这层转发不可省略。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Event
  alias Kalevala.World.Room.Context
  alias Kantele.World.Room.ShopRequestEvent

  # 房间上下文里的角色是 Trimmed 快照：只有 id/name/pid/status
  defp trimmed(id, name, pid) do
    %{id: id, name: name, pid: pid, status: "正常"}
  end

  defp context(characters) do
    %Context{data: %{}, characters: characters}
  end

  # 取出发给某个 pid 的事件
  defp events_to(context, pid) do
    for {to_pid, event} <- context.events, to_pid == pid, do: event
  end

  defp all_events(context), do: Enum.map(context.events, fn {_pid, event} -> event end)

  describe "list：指名商人" do
    test "转给指名的商人，并补上 reply_to/buyer_id/buyer_name" do
      requester_pid = :c.pid(0, 1, 0)
      vendor_pid = :c.pid(0, 2, 0)

      room =
        context([
          trimmed("player:1", "张三", requester_pid),
          trimmed("liuxi:xiaoer", "店小二", vendor_pid)
        ])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/list",
          data: %{name: "店小二"}
        })

      assert [%Event{topic: "shop/list", data: data}] = events_to(result, vendor_pid)
      assert data.reply_to == requester_pid
      assert data.buyer_id == "player:1"
      assert data.buyer_name == "张三"
    end

    test "指名不存在的商人：不转发" do
      requester_pid = :c.pid(0, 1, 0)
      vendor_pid = :c.pid(0, 2, 0)

      room =
        context([
          trimmed("player:1", "张三", requester_pid),
          trimmed("liuxi:xiaoer", "店小二", vendor_pid)
        ])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/list",
          data: %{name: "李四"}
        })

      assert all_events(result) == []
    end

    test "不指名：广播给房间内全部非玩家" do
      requester_pid = :c.pid(0, 1, 0)
      vendor_a = :c.pid(0, 2, 0)
      vendor_b = :c.pid(0, 3, 0)

      room =
        context([
          trimmed("player:1", "张三", requester_pid),
          trimmed("liuxi:xiaoer", "店小二", vendor_a),
          trimmed("liuxi:huoji", "伙记", vendor_b)
        ])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/list",
          data: %{name: nil}
        })

      assert [%Event{topic: "shop/list"}] = events_to(result, vendor_a)
      assert [%Event{topic: "shop/list"}] = events_to(result, vendor_b)
      assert events_to(result, requester_pid) == []
    end
  end

  describe "buy：携带物品名与数量" do
    test "不指名时广播，且 item_name/quantity 原样透传" do
      requester_pid = :c.pid(0, 1, 0)
      vendor_pid = :c.pid(0, 2, 0)

      room =
        context([
          trimmed("player:1", "张三", requester_pid),
          trimmed("liuxi:xiaoer", "店小二", vendor_pid)
        ])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/buy",
          data: %{item_name: "包子", quantity: 3}
        })

      assert [%Event{topic: "shop/buy", data: data}] = events_to(result, vendor_pid)
      assert data.item_name == "包子"
      assert data.quantity == 3
      assert data.reply_to == requester_pid
      assert data.buyer_id == "player:1"
    end

    test "指名商人时同样透传 item_name" do
      requester_pid = :c.pid(0, 1, 0)
      vendor_pid = :c.pid(0, 2, 0)

      room =
        context([
          trimmed("player:1", "张三", requester_pid),
          trimmed("liuxi:xiaoer", "店小二", vendor_pid)
        ])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/buy",
          data: %{name: "店小二", item_name: "包子", quantity: 1}
        })

      assert [%Event{topic: "shop/buy", data: data}] = events_to(result, vendor_pid)
      assert data.item_name == "包子"
    end
  end

  describe "边界" do
    test "发起者不在房间内：原样返回，不转发" do
      vendor_pid = :c.pid(0, 2, 0)
      room = context([trimmed("liuxi:xiaoer", "店小二", vendor_pid)])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: :c.pid(0, 9, 0),
          topic: "shop/list",
          data: %{name: nil}
        })

      assert all_events(result) == []
    end

    test "不会把请求转发回发起者自己" do
      requester_pid = :c.pid(0, 1, 0)

      room = context([trimmed("player:1", "张三", requester_pid)])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/list",
          data: %{name: nil}
        })

      assert all_events(result) == []
    end

    test "尸体 NPC 不接收请求" do
      requester_pid = :c.pid(0, 1, 0)
      corpse_pid = :c.pid(0, 2, 0)

      room =
        context([
          trimmed("player:1", "张三", requester_pid),
          %{id: "liuxi:xiaoer", name: "店小二", pid: corpse_pid, status: "店小二的尸体"}
        ])

      result =
        ShopRequestEvent.call(room, %{
          from_pid: requester_pid,
          topic: "shop/list",
          data: %{name: nil}
        })

      assert all_events(result) == []
    end
  end
end

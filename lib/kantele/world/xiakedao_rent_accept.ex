defmodule Kantele.World.XiakedaoRentAccept do
  @moduledoc """
  侠客岛黄衣使者 `accept_object/2` 收雇金分支（`d/xiakedao/npc/renter.c:175-246`）。

  NPC 进程只做 LPC 里同一进程内能做的事：校验钱币/未付报价/折扣、播报、
  从 `inquiry_state["rent_helpers"]` 摘掉被雇的师兄弟，然后把「扣钱 + 生成随从」
  以 `xiakedao/rent_return` 事件交给玩家进程（Ex 的背包属于玩家进程）。
  """

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kalevala.Event
  alias Kantele.Item, as: KItem
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  def handle(conn, npc, item_instance, data, _from_name) do
    reply_to = Map.get(data, :reply_to)
    room_id = Map.get(data, :npc_room_id) || Map.get(npc, :room_id)
    pending = Map.get(data, :pending_rent)

    cond do
      not currency?(item_instance) ->
        conn

      not is_map(pending) or not is_map(Map.get(pending, "helper")) ->
        say(conn, room_id, npc, "你给我钱干什么？赞助我们侠客岛么？")

      true ->
        helper = Map.get(pending, "helper")
        cost = cost_of(pending)
        paid = paid_amount(item(item_instance))

        cond do
          paid < cost ->
            conn = say(conn, room_id, npc, "我们这里可不能打折，你还是免了吧！")

            if paid * 2 >= cost and Map.get(data, :treat_skill) == true do
              broadcast(
                conn,
                room_id,
                "{name}跪在地上，抱着{npc}，哭喊道：“你就可怜可怜我这穷鬼吧！”\n" <>
                  "{npc}看了，颇为无奈，摇摇头，叹口气道：“好吧好吧，算了。”\n"
              )
              |> finish(npc, reply_to, data, helper, cost, item_instance, true)
            else
              conn
            end

          true ->
            finish(conn, npc, reply_to, data, helper, cost, item_instance, false)
        end
    end
  end

  defp finish(conn, npc, reply_to, data, helper, cost, item_instance, discount) do
    room_id = Map.get(data, :npc_room_id) || Map.get(npc, :room_id)
    npc_name = Map.get(npc, :name) || "黄衣使者"
    helper_name = Map.get(helper, "name") || "师弟"
    respect = Map.get(data, :respect) || "大侠"

    conn =
      conn
      |> broadcast(
        room_id,
        "{name}接过{npc}递过来的" <>
          item_name(item_instance) <>
          "，记在帐上，有道：“等会儿！”\n"
      )
      |> broadcast(room_id, "{npc}高声喊道：“#{helper_name}！快来，快来啊，送钱的上门了！”\n")
      |> broadcast(room_id, "{name}走了过来，看了看{npc}。\n")
      |> say(
        room_id,
        npc,
        "好啦，#{helper_name}，就是这位#{respect}，你一同去吧。"
      )
      |> broadcast(room_id, "{name}点点头，和{npc}寒暄两句，跟在了雇主身后。\n")

    conn = remove_helper(conn, npc, helper)

    if is_pid(reply_to) do
      send(reply_to, %Event{
        from_pid: self(),
        topic: "xiakedao/rent_return",
        data: %{
          ok: true,
          from_id: Map.get(data, :from_id),
          from_name: Map.get(data, :from_name),
          npc_id: Map.get(npc, :id),
          npc_name: npc_name,
          npc_room_id: room_id,
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          helper: helper,
          cost: cost,
          discount: discount
        }
      })
    end

    put_character(conn, current(conn))
  end

  # LPC set_temp("helpers", obs - ({ helper, 0 }))：雇主本人也从可选名单中消失。
  defp remove_helper(conn, npc, helper) do
    case conn.character.meta do
      %Kantele.Character.NonPlayerMeta{inquiry_state: state} when is_map(state) ->
        helpers =
          state
          |> Map.get("rent_helpers")
          |> case do
            list when is_list(list) ->
              Enum.reject(list, fn entry ->
                Map.get(entry, "id") == Map.get(helper, "id") or
                  Map.get(entry, :id) == Map.get(helper, "id")
              end)

            _ ->
              []
          end

        state = Map.put(state, "rent_helpers", helpers)
        meta = %{conn.character.meta | inquiry_state: state}
        put_character(conn, %{conn.character | meta: meta})

      _ ->
        conn
    end
  end

  defp currency?(item_instance) do
    case item(item_instance) do
      nil -> false
      item -> KItem.is_currency?(item)
    end
  end

  defp item(%{item_id: item_id}) do
    case Items.get(item_id) do
      {:ok, item} -> item
      _ -> nil
    end
  end

  defp item(_item_instance), do: nil

  # LPC `n = ob->value() / 10000`：Ex 的 currency_amount 就是铜钱价值，
  # 一两黄金 = 10000 文，故同样除以 10000。
  defp paid_amount(%{meta: meta}) do
    amount = Map.get(meta, "amount") || Map.get(meta, :amount) || 0
    div(amount, 10_000)
  end

  defp paid_amount(_item), do: 0

  defp item_name(item_instance) do
    case item(item_instance) do
      %{name: name} when is_binary(name) -> name
      _ -> "黄金"
    end
  end

  defp cost_of(pending) do
    case Map.get(pending, "cost") do
      cost when is_integer(cost) -> cost
      _ -> 10
    end
  end

  defp broadcast(conn, room_id, text) when is_binary(room_id),
    do: Helpers.broadcast(conn, room_id, text)

  defp broadcast(conn, _room_id, _text), do: conn

  defp say(conn, room_id, npc, text) when is_binary(room_id),
    do: Helpers.say(conn, room_id, Map.get(npc, :name) || "黄衣使者", text)

  defp say(conn, _room_id, _npc, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

defmodule Kantele.World.ItemOpen do
  @moduledoc """
  逐物品自定义 `open` / `unpack` / `dakai` 行为（LPC `init()` 里
  `add_action("do_open", "open"/"unpack"/"dakai")` 的忠实移植）。

  目前唯一一例：明教油布包（`d/mingjiao/obj/bag.c`）——打开后取出《楞伽经》，
  包内剩余本数记在**实例** `meta.book_count`（LPC `add("book_count", -1)` 改的是
  这一份 clone，不能写全局定义，否则所有玩家的包共用同一个计数）。

  `open/3` 返回 `{:done, conn}`（已处理）或 `:fallback`（交回房间开门逻辑）。
  """

  alias Kantele.Character.CommandView
  alias Kantele.World.Item, as: WorldItem
  alias Kantele.World.RoomActions.Helpers

  import Kalevala.Character.Conn

  @doc "按物品定义 id 派发自定义开包行为；无自定义行为返回 `:fallback`。"
  def open(conn, arg, character) do
    case find_item(character.inventory, arg) do
      nil ->
        :fallback

      instance ->
        case handler(Map.get(WorldItem.instance_item(instance), :id)) do
          nil -> :fallback
          fun -> fun.(conn, instance, character)
        end
    end
  end

  defp handler("mingjiao:items.bag"), do: &__MODULE__.OilclothBag.open/3
  defp handler(_), do: nil

  defp find_item(inventory, arg) when is_binary(arg) do
    Enum.find(inventory, fn instance ->
      WorldItem.matches?(WorldItem.instance_item(instance), arg)
    end)
  end

  defp find_item(_inventory, _arg), do: nil

  defmodule OilclothBag do
    @moduledoc """
    `d/mingjiao/obj/bag.c` `do_open`：从油布包里取出一本《楞伽经》。
    包内本数用尽后提示「里面什么也没有了」。
    """
    @book_id "mingjiao:items.jing"

    def open(conn, instance, character) do
      count = Map.get(instance.meta || %{}, :book_count, 1)

      if count < 1 do
        {:done, fail(conn, "油布包里面什么也没有了。\n")}
      else
        character = %{
          character
          | inventory: decrement(character.inventory, instance.id, count - 1)
        }

        conn
        |> put_character(character)
        |> Helpers.broadcast_vision(
          character.room_id,
          "$N轻轻地把油布包来看时，里面原来是一本薄薄的经书，只因油布包得紧密，虽长期藏在猿腹之中，书页仍然完好无损。"
        )
        |> Helpers.give_item(@book_id)
        |> then(&{:done, prompt(&1, CommandView, "prompt", %{})})
      end
    end

    defp decrement(inventory, instance_id, left) do
      Enum.map(inventory, fn inst ->
        if Map.get(inst, :id) == instance_id do
          %{inst | meta: Map.put(inst.meta || %{}, :book_count, left)}
        else
          inst
        end
      end)
    end

    defp fail(conn, text) do
      conn
      |> render(CommandView, "text", %{text: text})
      |> prompt(CommandView, "prompt", %{})
    end
  end
end

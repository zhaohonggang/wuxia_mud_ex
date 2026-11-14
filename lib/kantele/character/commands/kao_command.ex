defmodule Kantele.Character.KaoCommand do
  @moduledoc """
  烤肉命令：`kao <物品>` / `烤 <物品>`

  严格对齐 LPC `clone/misc/needfire.c::do_kao`：篝火自身注册
  `add_action("do_kao", "kao")`，故 `kao` 仅在房间内有篝火时可用。玩家
  `kao 野猪肉` 时，needfire 在玩家身上找生肉、调用其 `broil(me, this_object())`
  把 `raw_meat` 变成 `clone/food/meat`（烤肉）。

  - 前提：房间地面有篝火（item_id == clone_lib:needfire）
  - 生肉：背包中 `meta.raw_meat == true` 且 `meta.broil_to` 非空
  - 效果：消费生肉实例，按 `broil_to` 生成熟食实例进入背包
  """
  use Kalevala.Character.Command

  alias Kalevala.World.Item.Instance
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @needfire_id "clone_lib:needfire"

  def run(conn, %{"item_name" => ""}), do: no_arg(conn)

  def run(conn, %{"item_name" => item_name}) do
    unless room_has_needfire?(conn) do
      conn
      |> render(CommandView, "text", %{text: "这里没有篝火，没法烤东西。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case find_raw_meat(conn.character.inventory, item_name) do
        nil ->
          conn
          |> render(CommandView, "text", %{text: "你身上没有这样可烤的东西。\n"})
          |> prompt(CommandView, "prompt", %{})

        instance ->
          item = Items.get!(instance.item_id)
          broil_to = broil_target(item)

          if is_nil(broil_to) do
            conn
            |> render(CommandView, "text", %{text: "#{item.name} 没法在火上烤。\n"})
            |> prompt(CommandView, "prompt", %{})
          else
            broil(conn, conn.character, instance, item, broil_to)
          end
      end
    end
  end

  defp no_arg(conn) do
    conn
    |> render(CommandView, "text", %{text: "烤点什么东西呢？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp find_raw_meat(inventory, item_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      raw? = Map.get(item.meta, :raw_meat) || Map.get(item.meta, "raw_meat")
      broil? = broil_target(item)

      not is_nil(raw?) and raw? and not is_nil(broil?) and
        (instance.id == item_name || item.name == item_name ||
         item.callback_module.matches?(item, item_name))
    end)
  end

  defp broil_target(item) do
    case Map.get(item.meta, :broil_to) do
      nil -> Map.get(item.meta, "broil_to")
      v -> v
    end
  end

  defp broil(conn, character, instance, item, broil_to) do
    cooked = build_instance(broil_to)

    character =
      character
      |> Map.put(
        :inventory,
        [cooked | Enum.reject(character.inventory, &(&1.id == instance.id))]
      )

    conn
    |> put_character(character)
    |> Helpers.broadcast_vision(
      character.room_id,
      "$N用篝火把#{item.name}烤成了一块香喷喷的#{cooked.item.name}。",
      exclude_actor: true
    )
    |> render(CommandView, "text", %{
      text:
        "你用篝火把#{item.name}烤成了一块香喷喷的#{cooked.item.name}。\n"
    })
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  # 房间必须有篝火。生产环境走 Room.item_instances_by_id(room_id)；conn.private.room
  # 仅用于测试注入。conn.private.room 可能为 nil（房间进程尚未填充），须显式处理，
  # 否则 Map.get(nil, :private, %{}) 会抛 BadMapError。
  defp room_has_needfire?(conn) do
    room_id = conn.character.room_id

    from_room = Room.item_instances_by_id(room_id)

    from_conn =
      conn
      |> Map.get(:private, %{})
      |> Map.get(:room, nil)
      |> case do
        nil -> []
        room ->
          Map.get(room, :private, %{})
          |> Map.get(:item_instances, [])
      end

    (from_conn ++ from_room)
    |> Enum.any?(&needfire_instance?/1)
  end

  defp needfire_instance?(%Instance{item_id: @needfire_id}), do: true
  defp needfire_instance?(%Instance{item: %{id: @needfire_id}}), do: true
  defp needfire_instance?(_), do: false

  defp build_instance(item_id) do
    item = Items.get!(item_id)

    %Instance{
      id: Instance.generate_id(),
      item_id: item_id,
      item: item,
      created_at: DateTime.utc_now()
    }
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end

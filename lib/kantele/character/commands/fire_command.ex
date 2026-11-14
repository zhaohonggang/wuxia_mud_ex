defmodule Kantele.Character.FireCommand do
  @moduledoc """
  生火命令：`fire <木柴>` / `点火 <木柴>` / `生火 <木柴>`

  对齐 LPC `clone/misc/wood.c::fire()`：木柴 `set("fire_to", "/clone/misc/needfire")`，
  用火折（fire_source）对木柴使用触发 `fire()`，在所在房间生成一堆篝火并销毁木柴。

  EX 简化为单条命令：直接消费背包中带 `fire_to` 的木柴，在所
  在房间地面生成篝火。LPC 里「火折 fire_source 作前置」在此合并进同一条命令，
  以便狩猎→烤肉闭环可直接使用（玩家 `kao` 需要房间里有篝火）。
  """
  use Kalevala.Character.Command

  alias Kalevala.World.Item.Instance
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  def run(conn, %{"item_name" => ""}), do: no_arg(conn)

  def run(conn, %{"item_name" => item_name}) do
    case find_wood(conn.character.inventory, item_name) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你身上没有可以点火的东西。\n"})
        |> prompt(CommandView, "prompt", %{})

      instance ->
        item = Items.get!(instance.item_id)
        fire_to = fire_target(item)

        if is_nil(fire_to) do
          conn
          |> render(CommandView, "text", %{text: "#{item.name} 点不着火。\n"})
          |> prompt(CommandView, "prompt", %{})
        else
          start_fire(conn, conn.character, instance, item, fire_to)
        end
    end
  end

  defp no_arg(conn) do
    conn
    |> render(CommandView, "text", %{text: "点燃点什么东西呢？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp find_wood(inventory, item_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      fire_to = fire_target(item)

      not is_nil(fire_to) and
        (instance.id == item_name || item.name == item_name ||
         item.callback_module.matches?(item, item_name))
    end)
  end

  defp fire_target(item) do
    case Map.get(item.meta, :fire_to) do
      nil -> Map.get(item.meta, "fire_to")
      v -> v
    end
  end

  defp start_fire(conn, character, instance, item, fire_to) do
    fire = build_instance(fire_to)

    # 房间进程不存在时（测试 / 世界未启动）安全降级为 :error，不影响木柴消耗。
    _ = Room.add_item(character.room_id, fire)

    character =
      character
      |> Map.put(
        :inventory,
        Enum.reject(character.inventory, &(&1.id == instance.id))
      )

    conn
    |> put_character(character)
    |> Helpers.broadcast_vision(
      character.room_id,
      "$N用#{item.name}点起了一堆篝火。",
      exclude_actor: true
    )
    |> render(CommandView, "text", %{
      text: "你用#{item.name}点燃了一堆篝火，红红的火光映亮了四周。\n"
    })
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

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

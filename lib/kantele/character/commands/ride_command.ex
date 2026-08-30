defmodule Kantele.Character.RideCommand do
  @moduledoc """
  上马：`ride <坐骑>` / `qi <坐骑>`（cmds/std/ride.c）

  Batch 6 简化：坐骑为玩家背包中 `meta` 带 `"ridable" => true`（或
  `"type" => "mount"`）的物品；骑上后记录运行态 `meta.riding`，物品保留
  在背包。不做 LPC 的房间在场生物检定/守卫阻挡/重量对抗。

  新增：驾驶权限检查（Transport.can_drive_by?）——无主/自己/同房间车主可骑。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Item.Transport
  alias Kantele.Mount

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        conn
        |> render(CommandView, "text", %{text: "你要骑什么东西？\n"})
        |> prompt(CommandView, "prompt", %{})

      Map.get(conn.character.meta, :riding) != nil ->
        conn
        |> render(CommandView, "text", %{text: "你已经有座骑了！\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        do_ride(conn, rest)
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp do_ride(conn, name) do
    case find_mount(conn, name) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "这里没有这样的坐骑。\n"})
        |> prompt(CommandView, "prompt", %{})

      instance ->
        # 驾驶权限检查
        case Mount.can_ride?(instance, conn.character) do
          :ok ->
            riding = %{instance_id: instance.id, item_id: instance.item_id, name: instance.item.name}
            conn
            |> put_character(%{conn.character | meta: %{conn.character.meta | riding: riding}})
            |> render(CommandView, "text", %{text: "你飞身跃上#{instance.item.name}，身手很是矫捷。\n"})
            |> prompt(CommandView, "prompt", %{})

          {:error, msg} ->
            conn
            |> render(CommandView, "text", %{text: msg <> "\n"})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp find_mount(conn, name) do
    Enum.find(conn.character.inventory, fn instance ->
      item_matches?(instance.item, name) && ridable?(instance)
    end)
  end

  defp item_matches?(item, name) do
    is_map(item) && Map.get(item, :name) != nil &&
      String.downcase(item.name) == String.downcase(name)
  end

  defp ridable?(instance) do
    case Map.get(instance, :item) do
      %{meta: meta} when is_map(meta) ->
        Map.get(meta, "ridable") == true || Map.get(meta, "type") == "mount"

      _ ->
        false
    end
  end
end

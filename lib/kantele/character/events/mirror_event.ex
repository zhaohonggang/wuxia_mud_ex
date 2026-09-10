defmodule Kantele.Character.MirrorEvent do
  @moduledoc """
  乾坤宝镜发放结果处理（Q5-T3，玩家侧）

  子虚道人 ask 应答把 `mirror/give` 事件送回玩家进程；本模块校验每人限 1 个
  （手里已持有宝镜，或 `mirror_count` 已 ≥1）后把宝镜加入背包并落盘。
  未达标则只回话，不发镜。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.World.Item
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Items

  @mirror_item "liuxi:item/mirror"

  def give_result(conn, %{data: %{npc_name: npc_name, item_id: item_id, asker_id: asker_id}}) do
    character = conn.character

    cond do
      asker_id != character.id ->
        conn

      item_id != @mirror_item ->
        conn

      already_has_mirror?(character) || mirror_claimed?(character) ->
        conn
        |> render(CommandView, "text", %{
          text: "#{npc_name}捻须一笑：这位施主不是已有一面乾坤宝镜么，镜中寻物，镜外修身。\n"
        })
        |> prompt(CommandView, "prompt", %{})

      true ->
        case Items.get(item_id) do
          {:ok, item} ->
            instance = %Item.Instance{
              id: Item.Instance.generate_id(),
              item_id: item_id,
              created_at: DateTime.utc_now()
            }

            character = %{character | inventory: [instance | character.inventory]}
            Records.save(character)

            conn
            |> put_character(character)
            |> render(CommandView, "text", %{
              text: "#{npc_name}取出一面古镜，郑重递到你手中：持此宝镜，可寻回散落各地的江湖失物。\n"
            })
            |> prompt(CommandView, "prompt", %{})

          _ ->
            conn
        end
    end
  end

  def give_result(conn, _event), do: conn

  defp already_has_mirror?(character) do
    Enum.any?(character.inventory, fn instance -> instance.item_id == @mirror_item end)
  end

  defp mirror_claimed?(character) do
    Map.get(character.meta.stats, :mirror_count, 0) >= 1
  end
end
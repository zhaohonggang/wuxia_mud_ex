defmodule Kantele.Character.GiveEvent do
  @moduledoc """
  give 的两端处理（Batch 5）

  - 收受端 `characters/give`：把对方赠予的物品实例加入自己背包并落盘，回执赠与人
  - 赠与端 `give/result`：确认后从自己背包移除该物品并落盘，提示成功
  """

  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  # ---- 收受端 ----

  def receive(conn, %{data: %{item_instance: item_instance, from_name: from_name} = data}) do
    item_name = Map.get(data, :item_name) || "物品"
    character = conn.character

    case item_instance do
      nil ->
        deny(conn, from_name)

      _ ->
        inventory = [item_instance | character.inventory]
        character = %{character | inventory: inventory}

        send(
          Map.get(data, :reply_to),
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: true,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: character.id,
              from_id: Map.get(data, :from_id)
            }
          }
        )

        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: "#{from_name}给你#{item_name}。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp deny(conn, from_name) do
    conn
    |> render(CommandView, "text", %{text: "#{from_name}递来东西，但你无法接受。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 赠与端 ----

  def result(conn, %{data: %{ok: true, from_id: from_id, instance_id: instance_id}} = _event) do
    character = conn.character

    if from_id == character.id do
      inventory =
        Enum.reject(character.inventory, fn item_instance ->
          item_instance.id == instance_id
        end)

      character = %{character | inventory: inventory}
      Records.save(character)

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: "你把东西交给了对方。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
    end
  end

  def result(conn, %{data: %{ok: false}}) do
    conn
    |> render(CommandView, "text", %{text: "对方不肯收下。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, _event), do: conn
end

defmodule Kantele.Character.SummonCommand do
  @moduledoc """
  召唤物品命令：`summon <物品ID>`

  对应 LPC cmds/usr/summon.c。
  将已登记的物品召唤到身边，需要 can_summon 登记和精力 >= 200。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Damage
  alias Kantele.World.Items

  @jingli_cost 200

  def run(conn, %{"item" => item_id}) do
    character = conn.character

    cond do
      character.attributes["ghost"] == true ->
        conn
        |> render(CommandView, "text", %{text: "等你还了阳再召唤吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      !has_can_summon?(character, item_id) ->
        conn
        |> render(CommandView, "text", %{text: "你不知道如何召唤这个物品。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        do_summon(conn, character, item_id)
    end
  end

  def run(conn, %{}) do
    list_summonable(conn, conn.character)
  end

  defp has_can_summon?(character, item_id) do
    can_summon = character.attributes["can_summon"] || %{}
    Map.has_key?(can_summon, item_id)
  end

  defp list_summonable(conn, character) do
    can_summon = character.attributes["can_summon"] || %{}

    if map_size(can_summon) == 0 do
      conn
      |> render(CommandView, "text", %{text: "你现在可以召唤的物品有：\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      lines = ["你现在可以召唤的物品有：\n"]

      lines =
        Enum.reduce(can_summon, lines, fn {item_id, item_path}, acc ->
          item = load_item_template(item_path)
          name = if item, do: item.name, else: "未知物品"
          acc ++ ["物品ID：#{item_id}    物品名字：#{name}\n"]
        end)

      conn
      |> render(CommandView, "text", %{text: Enum.join(lines)})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp do_summon(conn, character, item_id) do
    can_summon = character.attributes["can_summon"] || %{}
    item_path = Map.get(can_summon, item_id)

    if is_nil(item_path) do
      conn
      |> render(CommandView, "text", %{text: "你不知道如何召唤这个物品。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      item_template = load_item_template(item_path)

      if is_nil(item_template) do
        conn
        |> render(CommandView, "text", %{text: "这个物品无法被召唤。\n"})
        |> prompt(CommandView, "prompt", %{})
      else
        attempt_summon(conn, character, item_id, item_template)
      end
    end
  end

  defp attempt_summon(conn, character, item_id, item_template) do
    vitals = character.meta.vitals
    jingli = is_map(vitals) && Map.get(vitals, :jingli, 0) || 0

    if jingli < @jingli_cost do
      conn
      |> render(CommandView, "text", %{text: "你试图呼唤#{item_template.name}，可是难以进入境界，看来是精力不济。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      {:ok, character} = Damage.receive_damage(character, :jingli, @jingli_cost)

      character = put_character(conn, character)

      conn
      |> render(CommandView, "text", %{
        text: summon_message(item_template.name)
      })
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp summon_message(item_name) do
    messages = [
      "你突然大喝一声，伸出右手凌空一抓，忽然乌云密布，雷声隐隐。\n\n只见#{item_name}破空而来 ……\n",
      "你一声长啸，四周金光散布，祥云朵朵，#{item_name}破空而来 ……\n\n"
    ]

    Enum.random(messages)
  end

  defp load_item_template(item_path) do
    try do
      path = item_path |> String.split("/") |> List.last()
      Items.get!(path)
    rescue
      _ -> nil
    end
  end
end

defmodule Kantele.Character.SanCommand do
  @moduledoc """
  圣化命令：`san <武器>`
  对应 LPC cmds/skill/san.c。
  向自制武器注入圣化标记，需要武器已充分浸入（imbue_ok），圣化后损失内力和精力上限。
  圣化数据落盘到物品实例 attrs["craft"]（运行时）。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Item.Craft
  alias Kantele.World.Items

  def run(conn, %{"arg" => arg}) do
    character = conn.character

    if arg == "" or is_nil(arg) do
      fail(conn, "你要圣化什么物品？\n")
    else
      case find_weapon(character, arg) do
        {:ok, item, instance} ->
          check_and_san(conn, character, item, instance)

        {:error, reason} ->
          fail(conn, reason <> "\n")
      end
    end
  end

  def run(conn, %{}) do
    fail(conn, "你要圣化什么物品？\n格式：san <武器名称>\n")
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp find_weapon(character, name) do
    instance =
      Enum.find(character.inventory, fn inst ->
        item = Items.get!(inst.item_id)
        item.callback_module.matches?(item, name)
      end)

    cond do
      is_nil(instance) ->
        {:error, "你身上没有这种物品"}

      true ->
        item = Items.get!(instance.item_id)
        craft_meta = get_craft_meta(instance)
        owner = craft_meta[:owner] || craft_meta["owner"] || %{}
        is_craft = is_map(owner) and map_size(owner) > 0

        if is_craft do
          {:ok, item, instance}
        else
          {:error, "#{item.name}没有办法被圣化"}
        end
    end
  end

  defp get_craft_meta(instance) do
    (instance.meta || %{})["craft"] || %{}
  end

  defp check_and_san(conn, character, item, instance) do
    craft_meta = get_craft_meta(instance)
    player_meta = player_meta_for_craft(character)
    normalized_craft = normalize_craft_meta_for_craft(craft_meta)
    item_meta_with_craft = Map.merge(item.meta || %{}, normalized_craft)

    case Craft.can_san?(item_meta_with_craft, player_meta) do
      :ok ->
        do_execute_san(conn, character, item, instance, normalized_craft, player_meta)

      {:error, reason} ->
        fail(conn, reason <> "\n")
    end
  end

  defp do_execute_san(conn, character, item, instance, craft_meta, player_meta) do
    new_meta = Craft.do_san(craft_meta, player_meta)
    new_attrs = Map.put(instance.meta || %{}, "craft", denormalize_craft_meta_from_craft(new_meta))
    new_instance = %{instance | meta: new_attrs}
    new_inventory = Enum.map(character.inventory, fn i -> if i.id == instance.id, do: new_instance, else: i end)

    new_character = %{character | inventory: new_inventory}
    Records.save(new_character)

    new_conn = put_character(conn, new_character)

    new_conn
    |> render(CommandView, "text", %{text: "你为#{item.name}注入了圣化标记，#{item.name}似乎泛起了一阵淡淡的光芒。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp normalize_craft_meta_for_craft(craft_meta) do
    magic = craft_meta["magic"] || craft_meta[:magic] || %{}
    owner = craft_meta["owner"] || craft_meta[:owner] || %{}
    %{
      magic: %{
        do_san: magic["do_san"] || magic[:do_san] || %{},
        power: magic["power"] || magic[:power] || 0,
        imbue_ok: magic["imbue_ok"] || magic[:imbue_ok] || false,
        imbue_ob: magic["imbue_ob"] || magic[:imbue_ob]
      },
      owner: owner
    }
  end

  defp denormalize_craft_meta_from_craft(craft_meta) do
    %{
      "owner" => craft_meta.owner,
      "magic" => %{
        "do_san" => craft_meta.magic.do_san,
        "power" => craft_meta.magic.power,
        "imbue_ok" => craft_meta.magic.imbue_ok,
        "imbue_ob" => craft_meta.magic.imbue_ob
      }
    }
  end

  defp player_meta_for_craft(character) do
    %{
      id: character.id,
      name: character.name,
      neili: character.meta.vitals.neili,
      max_neili: character.meta.vitals.max_neili,
      jingli: character.meta.vitals.jingli || 0,
      max_jingli: character.meta.vitals.max_jingli || 0,
      skills: character.meta.stats.skills
    }
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
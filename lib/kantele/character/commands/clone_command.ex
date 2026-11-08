defmodule Kantele.Character.CloneCommand do
  @moduledoc """
  克隆命令：`clone <物品或生物ID>`

  对应 LPC `cmds/wiz/clone.c`。
  巫师命令：从世界数据里复制物品或生物的实例。

  用法：
  - `clone <物品ID>`：克隆物品（模板 → 实例）
  - `clone <NPC ID>`：克隆生物（定义 → 新角色，如 `clone clone_lib:clone_tong_ren`）

  仅巫师可用。
  """

  use Kalevala.Character.Command

  alias Kalevala.Character
  alias Kantele.Character.CommandView
  alias Kantele.Admin.Access
  alias Kantele.Character.Presence
  alias Kantele.World

  def run(conn, %{"target" => target} = _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        case find_target(target) do
          nil ->
            return_error(conn, "找不到 #{target}。\n")

          %{type: "character", data: _target_char} = result ->
            handle_character_clone(conn, result, character)

          %{type: "item", data: item_template} ->
            instance = %Kalevala.World.Item.Instance{
              id: Kalevala.World.Item.Instance.generate_id(),
              item_id: item_template.id,
              created_at: DateTime.utc_now(),
              item: item_template
            }

            conn
            |> render(CommandView, "text", %{
              text: "克隆 #{item_template.name} 成功，ID: #{instance.id}\n"
            })
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  def run(conn, _params) do
    character = conn.character

    case Access.wizardp(character) do
      false ->
        return_error(conn, "你没有巫师的权限。\n")

      true ->
        conn
        |> render(CommandView, "text", %{text: "用法: clone <物品或生物ID>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp find_target(target) do
    characters = Presence.characters()

    if char = Enum.find(characters, &(String.downcase(&1.name) == String.downcase(target))) do
      %{type: "character", data: char}
    else
      case World.find_npc_definition(target) do
        nil ->
          case Kantele.World.Items.get(target) do
            {:ok, item} -> %{type: "item", data: item}
            _ -> nil
          end

        npc_def ->
          %{type: "character", data: npc_def}
      end
    end
  end

  defp handle_character_clone(conn, %{data: npc_def}, character) do
    clone = %{
      npc_def
      | id: Character.generate_id(),
        room_id: character.room_id
    }

    conn
    |> render(CommandView, "text", %{
      text: "克隆 #{npc_def.name} 成功，ID: #{clone.id}\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

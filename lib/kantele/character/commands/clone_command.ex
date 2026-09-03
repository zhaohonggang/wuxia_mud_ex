defmodule Kantele.Character.CloneCommand do
  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Presence

  def run(conn, %{"target" => target}) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    case find_target(target) do
      nil ->
        return_error(conn, "找不到 #{target}。")

      %{type: "character", data: _target_char} ->
        conn
        |> render(CommandView, "text", %{text: "生物克隆暂未实现，请使用 update 更新现有生物。\n"})
        |> prompt(CommandView, "prompt", %{})

      %{type: "item", data: item_template} ->
        instance = %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: item_template.id,
          created_at: DateTime.utc_now(),
          item: item_template
        }

        conn
        |> render(CommandView, "text", %{text: "克隆 #{item_template.name} 成功，ID: #{instance.id}\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, _params) do
    character = conn.character

    unless Access.wizardp(character) do
      return_error(conn, "你没有巫师的权限。")
    end

    conn
    |> render(CommandView, "text", %{text: "用法: clone <物品或生物ID>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp find_target(target) do
    characters = Presence.characters()

    if char = Enum.find(characters, &(String.downcase(&1.name) == String.downcase(target))) do
      %{type: "character", data: char}
    else
      case Kantele.World.Items.get(target) do
        nil -> nil
        item -> %{type: "item", data: item}
      end
    end
  end

  defp return_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

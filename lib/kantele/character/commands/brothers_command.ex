defmodule Kantele.Character.BrothersCommand do
  @moduledoc """
  结义命令：`brothers` | `brothers out <name>`

  对应 LPC cmds/usr/brothers.c
  查看结拜兄弟列表，或解除结义关系。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        list_brothers(conn)

      String.starts_with?(rest, "out ") ->
        name = String.trim(String.slice(rest, 4..-1))
        break_oath(conn, name)

      true ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：brothers | brothers out <name>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, %{}) do
    list_brothers(conn)
  end

  defp list_brothers(conn) do
    character = conn.character
    brothers = Map.get(character.meta, :brothers, %{})

    if map_size(brothers) == 0 do
      conn
      |> render(CommandView, "text", %{text: "你现在还没有结义的兄弟们。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      brother_list =
        brothers
        |> Enum.map(fn {id, name} -> "#{name}(#{id})" end)
        |> Enum.join("、")

      conn
      |> render(CommandView, "text", %{text: "你现在结义的兄弟有：#{brother_list}\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp break_oath(conn, name) do
    character = conn.character
    brothers = Map.get(character.meta, :brothers, %{})

    target_id = Enum.find(Map.keys(brothers), fn id -> brothers[id] == name end)

    if !target_id do
      conn
      |> render(CommandView, "text", %{text: "你现在没有这个结拜兄弟啊。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # Check for confirmation
      if character.meta.temp["pending/brother_out"] == target_id do
        # Confirmed - break the oath
        new_brothers = Map.delete(brothers, target_id)
        new_meta = Map.put(character.meta, :brothers, new_brothers)
        new_meta = Map.delete(new_meta, "pending/brother_out")
        new_character = %{character | meta: new_meta}
        new_conn = put_character(conn, new_character)

        new_conn
        |> render(CommandView, "text", %{text: "你和#{name}断绝了关系。\n"})
        |> prompt(CommandView, "prompt", %{})
        |> save()
        # TODO: Notify the other player and remove from their brothers list
      else
        # First time - ask for confirmation
        new_meta = Map.put(character.meta, "pending/brother_out", target_id)
        new_character = %{character | meta: new_meta}
        new_conn = put_character(conn, new_character)

        new_conn
        |> render(CommandView, "text", %{text: "你确定要和这位朋友(#{name})割袍断义吗？\n如果你确定，请再输入一次这条命令。\n"})
        |> prompt(CommandView, "prompt", %{})
        |> save()
      end
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
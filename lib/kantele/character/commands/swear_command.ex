defmodule Kantele.Character.SwearCommand do
  @moduledoc """
  结拜命令：`swear with <玩家>` | `swear cancel`

  对应 LPC cmds/usr/swear.c
  与其他玩家结拜结义，需双方同意。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    cond do
      arg == "" ->
        conn
        |> render(CommandView, "text", %{text: "你要和谁一同结义？\n"})
        |> prompt(CommandView, "prompt", %{})

      arg == "cancel" ->
        cancel_swear(conn)

      String.starts_with?(arg, "with ") ->
        name = String.trim(String.slice(arg, 5..-1))
        request_swear(conn, name)

      true ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：swear with <玩家> | swear cancel\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：swear with <玩家> | swear cancel\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp request_swear(conn, name) do
    character = conn.character

    cond do
      character.meta.combat.enemies != [] ->
        conn
        |> render(CommandView, "text", %{text: "好好忙你手头的事情！\n"})
        |> prompt(CommandView, "prompt", %{})

      character.meta.temp["busy"] ->
        conn
        |> render(CommandView, "text", %{text: "好好忙你手头的事情！\n"})
        |> prompt(CommandView, "prompt", %{})

      character.attributes["age"] < 18 ->
        conn
        |> render(CommandView, "text", %{text: "小毛孩子捣什么乱？一边玩去！\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        # Check if there's an existing pending request
        if character.meta.temp["pending/swear"] do
          conn
          |> render(CommandView, "text", %{text: "你正在向人家提出请求呢，可是人家还没有答应你。\n"})
          |> prompt(CommandView, "prompt", %{})
        else
          conn
          |> event("swear/request", %{target_name: name})
          |> assign(:prompt, false)
        end
    end
  end

  defp cancel_swear(conn) do
    character = conn.character

    if character.meta.temp["pending/swear"] do
      new_meta = Map.delete(character.meta.temp, "pending/swear")
      new_meta = Map.put(character.meta, :temp, new_meta)
      new_character = %{character | meta: new_meta}
      new_conn = put_character(conn, new_character)

      new_conn
      |> render(CommandView, "text", %{text: "你打消了结义的念头。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    else
      conn
      |> render(CommandView, "text", %{text: "你现在没有提出结义请求。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
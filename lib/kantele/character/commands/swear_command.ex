defmodule Kantele.Character.SwearCommand do
  @moduledoc """
  结拜命令：`swear with <玩家>` | `swear cancel`

  对应 LPC cmds/usr/swear.c
  与其他玩家结拜结义，需双方同意（对方用 right/refuse 回应）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

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
      busy?(character) or fighting?(character) ->
        conn
        |> render(CommandView, "text", %{text: "好好忙你手头的事情！\n"})
        |> prompt(CommandView, "prompt", %{})

      age(character) < 18 ->
        conn
        |> render(CommandView, "text", %{text: "小毛孩子捣什么乱？一边玩去！\n"})
        |> prompt(CommandView, "prompt", %{})

      PlayerMeta.get_temp(character.meta, "pending/swear") != nil ->
        conn
        |> render(CommandView, "text", %{text: "你正在向人家提出请求呢，可是人家还没有答应你。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        # 交给房间解析目标并转发请求
        conn
        |> event("swear/request", %{target_name: name})
        |> assign(:prompt, false)
    end
  end

  defp cancel_swear(conn) do
    character = conn.character

    if PlayerMeta.get_temp(character.meta, "pending/swear") do
      meta = PlayerMeta.delete_temp(character.meta, "pending/swear")
      new_conn = put_character(conn, %{character | meta: meta})

      # 通知房间取消（清除对方 pending/answer 标记）
      new_conn =
        event(new_conn, "swear/cancel", %{
          target_name: PlayerMeta.get_temp(character.meta, "pending/swear")
        })

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

  defp busy?(character), do: PlayerMeta.get_temp(character.meta, "busy") != nil

  defp fighting?(character), do: character.meta.combat.enemies != []

  defp age(character), do: character.attributes["age"] || 0

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end
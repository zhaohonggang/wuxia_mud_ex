defmodule Kantele.Character.EngageCommand do
  @moduledoc """
  求婚命令：`engage <对方> <承诺>` | `engage cancel`

  对应 LPC cmds/usr/engage.c；按迁移计划采用「口令匹配」两段式：
  求婚方 `engage <对方> <承诺>`，被求婚方用 `accede <承诺>` 应婚。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    cond do
      arg == "" ->
        conn
        |> render(CommandView, "text", %{text: "你要向谁求婚？\n"})
        |> prompt(CommandView, "prompt", %{})

      arg == "cancel" ->
        cancel_engage(conn)

      true ->
        request_engage(conn, arg)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：engage <对方> <承诺> | engage cancel\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp request_engage(conn, arg) do
    character = conn.character

    case String.split(arg, ~r/\s+/, parts: 2) do
      [name, promise] when promise != "" ->
        cond do
          busy?(character) or fighting?(character) ->
            render_msg(conn, "好好忙你手头的事情！\n")

          age(character) < 18 ->
            render_msg(conn, "小毛孩子捣什么乱？一边玩去！\n")

          PlayerMeta.spouse(character.meta) != nil ->
            render_msg(conn, "你可要稳住！根据泥潭法典第九十九条，重婚者打入地狱！\n")

          PlayerMeta.get_temp(character.meta, "pending/engage") != nil ->
            render_msg(conn, "你正在向人家求婚呢，可是人家还没有答应你。\n")

          true ->
            # 交给房间解析目标并转发求婚请求
            conn
            |> event("engage/request", %{target_name: name, promise: promise})
            |> assign(:prompt, false)
        end

      _ ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：engage <对方> <承诺>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp cancel_engage(conn) do
    character = conn.character

    if pending = PlayerMeta.get_temp(character.meta, "pending/engage") do
      meta =
        character.meta
        |> PlayerMeta.delete_temp("pending/engage")
        |> PlayerMeta.delete_temp("pending/engage_target_id")
        |> PlayerMeta.delete_temp("pending/engage_promise")

      new_conn = put_character(conn, %{character | meta: meta})

      new_conn =
        event(new_conn, "engage/cancel", %{
          target_name: pending
        })

      new_conn
      |> render(CommandView, "text", %{text: "你打消了求婚的念头。\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    else
      render_msg(conn, "你现在没有向任何人求婚。\n")
    end
  end

  defp busy?(character), do: PlayerMeta.get_temp(character.meta, "busy") != nil

  defp fighting?(character), do: character.meta.combat.enemies != []

  defp age(character), do: character.attributes["age"] || 0

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end

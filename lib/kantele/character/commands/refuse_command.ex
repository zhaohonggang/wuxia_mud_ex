defmodule Kantele.Character.RefuseCommand do
  @moduledoc """
  拒绝命令：`refuse <玩家>`

  对应 LPC cmds/std/refuse.c
  拒绝对方提出的结拜请求。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    if arg == "" do
      conn
      |> render(CommandView, "text", %{text: "你要拒绝谁？\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      reply(conn, "refuse", arg)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要拒绝谁？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, answer, name) do
    character = conn.character
    requester_id = PlayerMeta.get_temp(character.meta, "pending/swear_from_id")

    cond do
      is_nil(requester_id) ->
        conn
        |> render(CommandView, "text", %{text: "这人没有向你提出什么要求啊？\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        conn
        |> event("swear/answer", %{answer: answer, target_name: name})
        |> assign(:prompt, false)
    end
  end
end
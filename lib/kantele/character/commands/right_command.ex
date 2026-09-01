defmodule Kantele.Character.RightCommand do
  @moduledoc """
  答应命令：`right <玩家>`

  对应 LPC cmds/std/right.c
  答应对方提出的结拜请求。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    if arg == "" do
      conn
      |> render(CommandView, "text", %{text: "你要答应谁？\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      reply(conn, "right", arg)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要答应谁？\n"})
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
        # 交给房间匹配请求者并完成结拜
        conn
        |> event("swear/answer", %{answer: answer, target_name: name})
        |> assign(:prompt, false)
    end
  end
end
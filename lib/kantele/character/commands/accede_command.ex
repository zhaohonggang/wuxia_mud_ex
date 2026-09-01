defmodule Kantele.Character.AccedeCommand do
  @moduledoc """
  应婚命令：`accede <承诺>`

  对应 LPC cmds/usr/accede.c；按迁移计划采用「口令匹配」语义：
  对方求婚时的承诺与你输入的承诺一致，则答应（交给房间双写 meta.spouse）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    if arg == "" do
      conn
      |> render(CommandView, "text", %{text: "你要应允谁的承诺？格式：accede <承诺>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      reply(conn, arg)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要应允谁的承诺？格式：accede <承诺>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, promise) do
    character = conn.character

    case {PlayerMeta.get_temp(character.meta, "pending/engage_promise"),
          PlayerMeta.get_temp(character.meta, "pending/engage_from_name")} do
      {nil, _} ->
        render_msg(conn, "刚才没人向你求婚，你应允谁？\n")

      {held, requester_name} ->
        if held == promise do
          # 交给房间匹配求婚方并完成婚约
          conn
          |> event("engage/answer", %{target_name: requester_name, promise: promise})
          |> assign(:prompt, false)
        else
          render_msg(conn, "你犹豫了半天，觉得承诺似乎对不上，还是没答应。\n")
        end
    end
  end

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

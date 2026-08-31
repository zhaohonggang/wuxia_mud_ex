defmodule Kantele.Character.SemoteCommand do
  @moduledoc """
  表情列表命令：`semote`

  对应 LPC cmds/std/semote.c。
  查看表情动词列表。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.{Emotes, CommandView}

  def run(conn, _params) do
    emotes = Enum.sort(Emotes.keys())

    msg =
      Enum.reduce(emotes, "江湖表情列表：\n", fn emote, acc ->
        "#{acc}  #{emote}\n"
      end)

    conn
    |> render(CommandView, "text", %{text: msg})
    |> prompt(CommandView, "prompt", %{})
  end
end

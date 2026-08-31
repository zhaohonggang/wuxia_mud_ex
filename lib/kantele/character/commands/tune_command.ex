defmodule Kantele.Character.TuneCommand do
  @moduledoc """
  频道设置命令：`tune [频道名]`

  对应 LPC cmds/std/tune.c
  管理玩家收听的频道列表。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"channel" => channel}) do
    character = conn.character
    channels = Map.get(character.meta, :channels, [])

    if Enum.member?(channels, channel) do
      new_channels = List.delete(channels, channel)
      new_meta = Map.put(character.meta, :channels, new_channels)

      conn
      |> put_character(%{character | meta: new_meta})
      |> render(CommandView, "text", %{text: "关闭 #{channel} 频道。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      render_error(conn, "要打开某个频道只要用该频道说话即可。\n")
    end
  end

  def run(conn, %{}) do
    character = conn.character
    channels = Map.get(character.meta, :channels, [])

    if channels == [] or channels == nil do
      conn
      |> render(CommandView, "text", %{text: "你现在并没有收听任何频道。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      channel_list = Enum.join(channels, ", ")

      conn
      |> render(CommandView, "text", %{text: "你现在收听的频道：#{channel_list}。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  def run_bare(conn, _params) do
    run(conn, %{})
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end

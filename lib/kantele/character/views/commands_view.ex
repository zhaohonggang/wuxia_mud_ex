defmodule Kantele.Character.CommandsView do
  @moduledoc """
  commands 命令的输出渲染
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("index", %{commands: commands}) do
    lines = ["可用命令："] ++ Enum.map(commands, fn command -> render("_command", %{command: command}) end)
    %EventText{
      topic: "Commands.Index",
      data: %{commands: commands},
      text: Enum.join(lines, "\n") <> "\n"
    }
  end

  def render("_command", %{command: %{name: name, description: description}}) do
    padding = String.pad_trailing(name, 12)

    case description do
      "" -> ~i(  {color foreground="white"}#{padding}{/color})
      desc -> ~i(  {color foreground="white"}#{padding}{/color} #{desc})
    end
  end
end

defmodule Kantele.Character.CommandsView do
  @moduledoc """
  commands 命令的输出渲染
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("index", %{commands: commands}) do
    %EventText{
      topic: "Commands.Index",
      data: %{commands: commands},
      text:
        ["可用命令：\n"] ++
          Enum.map(commands, fn command -> render("_command", %{command: command}) end)
    }
  end

  def render("_command", %{command: %{name: name, description: description}}) do
    padding = String.pad_trailing(name, 12)

    case description do
      "" -> ~i(  {color foreground="white"}#{padding}{/color}\n)
      desc -> ~i(  {color foreground="white"}#{padding}{/color} #{desc}\n)
    end
  end
end

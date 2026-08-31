defmodule Kantele.Character.QuestCommand do
  @moduledoc """
  任务命令：`quest`

  对应 LPC cmds/usr/quest.c
  领取和完成任务。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "任务系统暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

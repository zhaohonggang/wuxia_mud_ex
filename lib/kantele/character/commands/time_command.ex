defmodule Kantele.Character.TimeCommand do
  @moduledoc """
  时间命令：`time`

  对应 LPC cmds/usr/time.c
  显示游戏时间和现实时间。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()

    time_str = "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(minute)}:#{pad(second)}"

    conn
    |> render(CommandView, "text", %{text: "现在北京时间是：#{time_str}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end

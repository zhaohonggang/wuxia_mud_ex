defmodule Kantele.Character.BjtimeCommand do
  @moduledoc """
  北京时间命令：`bjtime`

  对应 LPC cmds/usr/bjtime.c
  显示当前北京时间。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    now_str = :calendar.local_time() |> elem(1) |> format_time()

    conn
    |> render(CommandView, "text", %{text: "现在的时间是北京时间 #{now_str}。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp format_time({hour, minute, second}) do
    "#{pad(hour)}:#{pad(minute)}:#{pad(second)}"
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end

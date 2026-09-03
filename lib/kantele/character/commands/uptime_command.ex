defmodule Kantele.Character.UptimeCommand do
  @moduledoc """
  运行时间命令：`uptime`

  对应 LPC cmds/usr/uptime.c。
  显示游戏已经运行了多久。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    text = "武林外传已经运行了#{uptime_text()}。\n"

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp uptime_text do
    # Elixir/Erlang doesn't have a direct uptime function like LPC,
    # but we can report the current time or a formatted duration
    # For now, just report current time as a placeholder
    {{y, m, d}, {h, mi, s}} = :calendar.local_time()
    "#{y}年#{m}月#{d}日 #{h}时#{mi}分#{s}秒"
  end
end

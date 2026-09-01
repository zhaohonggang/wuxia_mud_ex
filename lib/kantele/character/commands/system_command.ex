defmodule Kantele.Character.SystemCommand do
  @moduledoc """
  系统命令：`system`

  对应 LPC cmds/usr/system.c。
  显示系统资源使用情况（Elixir/Erlang 虚拟机信息）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    memory = :erlang.memory()

    msg = """
    游戏系统资源状态：

    虚拟机内存使用：
      总内存：#{div(Keyword.get(memory, :total, 0), 1024 * 1024)} MB
      进程内存：#{div(Keyword.get(memory, :processes, 0), 1024 * 1024)} MB
      原子表：#{div(Keyword.get(memory, :atom, 0), 1024)} KB
      二进制：#{div(Keyword.get(memory, :binary, 0), 1024 * 1024)} MB

    运行时间：#{format_uptime()}
    进程数：#{length(:erlang.processes())}
    """

    conn
    |> render(CommandView, "text", %{text: msg})
    |> prompt(CommandView, "prompt", %{})
  end

  defp format_uptime do
    elapsed = :erlang.statistics(:wall_clock)
    seconds = div(elem(elapsed, 0), 1000)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    days = div(hours, 24)

    "#{days}天#{rem(hours, 24)}小时#{rem(minutes, 60)}分钟"
  end
end

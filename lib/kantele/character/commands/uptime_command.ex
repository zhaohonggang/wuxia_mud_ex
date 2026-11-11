defmodule Kantele.Character.UptimeCommand do
  @moduledoc """
  运行时间命令：`uptime`

  对应 LPC cmds/usr/uptime.c。
  显示游戏已经运行了多久。

  LPC 原实现用 `uptime()`（驱动启动至今的秒数）配合 `chinese_number()` 把
  天/时/分/秒拼成中文串（`NAME 已经执行了{time}。\n`）。本端口取 beam 启动至今
  的秒数（`:erlang.statistics(:wall_clock)`，与 `MudinfoCommand` 同源），再经
  `format_uptime/1` 用 `Kantele.Util.ChineseNumber` 还原 LPC 的中文时长文案。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Util.ChineseNumber

  def run(conn, _params) do
    text = "武林外传已经运行了#{uptime_text()}。\n"

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  @doc """
  把「从启动至今的秒数」格式化为中文时长（天/时/分/秒）。

  对齐 LPC `uptime.c` 的拼接规则：
  - 天、时、分仅在 >0 时输出（为 0 时省略，不输出「零天/零小时/零分」）；
  - 秒始终输出（即便为 0 也输出「零秒」）。

  例：`format_uptime(90_061)` → `"一天一小时一分一秒"`。
  """
  def format_uptime(seconds) when is_integer(seconds) and seconds >= 0 do
    d = div(seconds, 86_400)
    h = div(rem(seconds, 86_400), 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)

    parts = []
    parts = if d > 0, do: parts ++ [ChineseNumber.to_chinese(d) <> "天"], else: parts
    parts = if h > 0, do: parts ++ [ChineseNumber.to_chinese(h) <> "小时"], else: parts
    parts = if m > 0, do: parts ++ [ChineseNumber.to_chinese(m) <> "分"], else: parts
    parts = parts ++ [ChineseNumber.to_chinese(s) <> "秒"]

    Enum.join(parts, "")
  end

  defp uptime_text do
    seconds = :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    format_uptime(seconds)
  end
end

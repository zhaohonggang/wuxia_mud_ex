defmodule Kantele.Character.WorldStatusView do
  use Kalevala.Character.View

  def render("display", %{last_load: nil}) do
    "世界尚未加载过（启动中或加载进程未运行）。\n"
  end

  def render("display", %{last_load: %{status: :ok, at: at}}) do
    "上次世界加载：{color foreground=\"green\"}成功{/color}\n时间：#{format_time(at)}\n"
  end

  def render("display", %{last_load: %{status: :error, at: at, error: error, file: file}}) do
    location =
      case file do
        nil ->
          ""

        file ->
          "\n文件：#{file}"
      end

    "上次世界加载：{color foreground=\"red\"}失败{/color}\n时间：#{format_time(at)}#{location}\n原因：#{error}\n旧世界保持运行，修复数据文件后可再次 reload。\n"
  end

  defp format_time(at) do
    "#{DateTime.to_iso8601(at)} UTC"
  end
end

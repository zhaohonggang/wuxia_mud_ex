defmodule Kantele.World.LoaderError do
  @moduledoc """
  世界数据加载/解析失败

  尽量附带出错的文件路径（`file`）与原始异常（`reason`），供上层日志、
  reload 回执与 `/health` 展示时能直接定位到写坏的 .ucl 文件。
  """

  defexception [:message, :file, :reason]

  @impl true
  def message(%{message: message, file: file, reason: reason}) do
    reason_text = reason_message(reason)

    case file do
      nil -> "#{message}: #{reason_text}"
      file -> "#{message}（#{file}）：#{reason_text}"
    end
  end

  defp reason_message(nil), do: "未知错误"

  defp reason_message(reason) do
    Exception.message(reason) || inspect(reason)
  end
end

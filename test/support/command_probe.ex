defmodule Kantele.CommandProbe do
  @moduledoc """
  命令占位桩探测器（P0 基座）

  遍历 `lib/kantele/character/commands/` 下全部 `*_command.ex` 源文件，
  按文本标记把每个命令模块判定为 `:real` / `:stub` 之一。

  判定规则：
  - 源码含占位文案标记（如 "暂未开放"/"暂未实现"）→ `:stub`
  - 否则 → `:real`

  配套的 `assert_no_unmentioned_stubs/0` 会在测试里断言：除显式白名单
  外，不应出现新的占位桩，从而防止未来占位桩失控（对应 MIGRATION_PLAN §3.2）。
  """

  @commands_dir Path.expand("../../lib/kantele/character/commands", __DIR__)

  @stub_markers [
    "暂未开放",
    "暂未实现",
    "还没实现",
    "尚未开放",
    "系统暂未"
  ]

  @doc "扫描全部命令源文件，返回 `[%{file:, status:}]` 列表"
  def scan do
    @commands_dir
    |> Path.join("*.ex")
    |> Path.wildcard()
    |> Enum.map(&classify_file/1)
  end

  @doc "返回被判定为占位桩的命令文件列表"
  def stubs, do: scan() |> Enum.filter(&(&1.status == :stub))

  @doc "返回判定为真实实现的命令文件列表"
  def reals, do: scan() |> Enum.filter(&(&1.status == :real))

  defp classify_file(path) do
    %{file: Path.basename(path, ".ex"), status: status(File.read!(path))}
  end

  defp status(source) do
    if Enum.any?(@stub_markers, &String.contains?(source, &1)), do: :stub, else: :real
  end
end

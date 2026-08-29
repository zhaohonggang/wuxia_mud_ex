defmodule Kantele.Editor.Line do
  @moduledoc """
  简易行编辑器（对应 `feature/edit.c`）

  `edit.c` 是 `input_to` 驱动的逐行收集：`.` 结束、`~q` 取消、`~e` 转内建 vi、
  其余追加一行。本模块把这段逻辑抽成纯状态机，宿主（Kalevala 命令）用任意输入
  循环即可驱动。

  状态：`%{lines: [string]}`，累积的每一行不含换行；结束时用 `\n` join。
  """

  @doc "编辑会话初始化文案（对应 edit.c edit/1 的开场白）"
  def instructions() do
    "结束离开用 '.'，取消输入用 '~q'，使用内建列编辑器用 '~e'。\n" <>
      "----------------------------------------------------------\n"
  end

  @doc "开始新会话（可选首行）"
  def new(lines \\ []) when is_list(lines), do: %{lines: lines}

  @doc """
  累计状态机的迁移函数（对应 edit.c input_line/3）

  - 输入 `"."` → `{:done, text}`（text = \n join 全部行）
  - 输入 `"~q"` → `:cancel`（弃稿）
  - 输入 `"~e"` → `:use_vi`（跳转全屏编辑器，宿主决定回落）
  - 其余 → `{:continue, new_state}`（追加该行）
  """
  def accumulate(%{lines: lines} = state, "."), do: {state, {:done, Enum.join(lines, "\n")}}
  def accumulate(%{} = state, "~q"), do: {state, :cancel}
  def accumulate(%{} = state, "~e"), do: {state, :use_vi}
  def accumulate(%{lines: lines} = state, line) when is_binary(line), do: {%{state | lines: lines ++ [line]}, :continue}
end
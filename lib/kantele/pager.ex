defmodule Kantele.Pager do
  @moduledoc """
  分页器（对应 `feature/more.c more_file/4` 的纯逻辑）

  宿主持有 `text`（行列表）+ 光标的 `current_line`/`total`，逐页渲染；本模块
  仅负责把用户的翻页命令解析成 `(start_line, page_size)`（含前进/后退/跳行/
  负偏移/钳制），并给出页码/进度文案。终端转义与 `input_to` 循环由宿主接管。

  命令语义（忠实移植 more.c）：
  - `""` 默认下页（LINES_PER_PAGE=30）
  - `"q"` 离开
  - `"b"` 前两页；到顶则回顶
  - `"t"` 跳回顶部
  - `"N"` 跳到第 N 行
  - `"nN"` 显示接续 N 行
  - `"a,b"` 显示第 a 到 b 行（a>b 自动交换）
  - 负行号 = 从末尾倒数；负页长 = 上一页
  """

  @lines_per_page 30

  @doc "每页行数（more.c LINES_PER_PAGE）"
  def lines_per_page(), do: @lines_per_page

  @doc """
  解析翻页命令

  ## 返回
  - `{:page, start_line, size}` — 本次要显示的行区间（1-based）
  - `:quit` — 离开
  - `{:error, msg}` — 非法（如 >300 行）
  """
  def resolve(cmd, current_line, total, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, @lines_per_page)
    cmd = cmd || ""

    cond do
      cmd == "q" ->
        :quit

      true ->
        {goto_line, page} = parse(cmd, current_line, page_size)
        clamp(goto_line, page, total)
    end
  end

  defp clamp(goto_line, page, total) do
    cond do
      page > 301 ->
        {:error, "连续显示的行数必须小于等于300。\n"}

      true ->
        goto_line = if goto_line == 0, do: 1, else: goto_line
        page = if page == 0, do: 1, else: page

        {goto_line, page} =
          cond do
            goto_line < 0 ->
              gl = goto_line + total
              {if(gl < 1, do: 1, else: gl), page}

            page < 0 ->
              gl = goto_line + page
              gl = if gl < 1, do: 1, else: gl
              {gl, -page}

            true ->
              {goto_line, page}
          end

        {:page, goto_line, page}
    end
  end

  @doc "是否已到文末（从 start_line 起 size 行覆盖 total）"
  def at_end?(start_line, size, total), do: start_line + size - 1 >= total

  @doc "当前进度百分比（more.c `line * 100 / sizeof(text)`，display 用）"
  def progress_percent(start_line, total) when total > 0 do
    div(min(start_line, total) * 100, total)
  end

  def progress_percent(_start_line, _total), do: 100

  @doc "是否读取完毕（more.c i==sizeof-1 / 无更多）"
  def read_done?(start_line, size, total), do: at_end?(start_line, size, total)

  # ---- 命令解析（more_file 语义）----

  defp parse(cmd, line, ps) do
    case String.split(cmd, ",", parts: 2) do
      [a, b] ->
        case {Integer.parse(a), Integer.parse(b)} do
          {{ga, ""}, {gb, ""}} -> range(ga, gb)
          _ -> next(line, ps)
        end

      [_] ->
        cond do
          String.starts_with?(cmd, "n") ->
            case Integer.parse(String.slice(cmd, 1..-1)) do
              {n, ""} -> {line, n}
              _ -> next(line, ps)
            end

          match?({_, ""}, Integer.parse(cmd)) ->
            {elem(Integer.parse(cmd), 0), ps}

          cmd == "b" -> back(line, ps)
          cmd == "t" -> {1, ps}
          true -> next(line, ps)
        end
    end
  end

  defp range(a, b) do
    if b < a do
      {b, a - b + 1}
    else
      {a, b - a + 1}
    end
  end

  defp next(line, ps), do: {line, ps}

  defp back(line, ps) do
    new_line = line - ps * 2
    if new_line > 1, do: {new_line, ps}, else: {1, ps}
  end
end
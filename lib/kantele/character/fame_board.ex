defmodule Kantele.Character.FameBoard do
  @moduledoc """
  `top2` / `topp` 的门派 / 结义同盟声望榜（LPC `cmds/usr/top2.c`、`topp.c`）。

  LPC 里 `top2.c` 与 `topp.c` 是**内容完全相同的两份源码**（连 help 都写着
  `top [family | league]`），所以 Ex 侧把渲染收敛到本模块，两个命令模块只负责
  取参和输出。

  ## LPC 行为逐条落地

  - `!arg || arg == "family"` → 门派榜；`arg == "league"` → 同盟榜；
    其它 → `你要看什么排行榜？`
  - 门派：`FAMILY_D->query_family_fame()` + `query_all_last_family_fame()`，
    按声望**降序**，不截断；无数据也照样打印表头与「一共是零个门派。」
  - 同盟：`LEAGUE_D->query_league_fame()` + `query_all_last_league_fame()`，
    空榜直接 `notify_fail("目前江湖上没有什么有名的结义同盟。")`，
    非空最多列 **30** 条（`i < 30`）
  - 每行 `"%2d. %-12s  %-9d(%s%d%s)"`：`delta = fame - last[fam]`，
    正数带 `+`，负数自带 `-`，0 就是 `0`
  - 结尾 `chinese_number(i)` → `Kantele.Util.ChineseNumber.to_chinese/1`；
    门派用「一共是X个门派。」，同盟用「列出了X个结义同盟。」

  ## 与 LPC 的差异

  1. **ANSI**：原版用 `WHT/HIY/HIR` 给标题、分隔线和正负 delta 上色。本服的
     输出管线会自行着色（见 `Kantele.Output.SemanticColors`），这里只出纯文本。
  2. **列宽**：LPC `%-12s` 按**字节**补齐，中文名在不同编码下会歪；这里按终端
     显示列宽算（CJK 计 2 列），保证中文门派名对齐。
  3. **数据源**：`FAMILY_D` 用 `Kantele.FamilyFame`（移植了 `base_family_fame`
     静态表），`LEAGUE_D` 用 `Kantele.League`。两者都保留「昨日快照」，
     但 Ex 侧暂无 LPC 的 1800 秒心跳，快照需由上层调用
     `FamilyFame.snapshot/0` / `League.snapshot_last_fame/0` 主动推进；
     未推进时 delta 恒为 0，与 LPC「无昨日数据」一致。

  ## 测试注入

  单测可向 `conn.private` 塞 `:fame_board`：

      %{family: %{current: %{"少林寺" => 10}, last: %{"少林寺" => 8}},
        league: %{current: %{}, last: %{}}}

  避免依赖 ETS 中的真实榜单。注意 `conn.private` 是
  `Kalevala.Character.Conn.Private` 结构体、未实现 `Access`，一律用
  `Map.get/2`。
  """

  alias Kantele.FamilyFame
  alias Kantele.League
  alias Kantele.Util.ChineseNumber

  @separator "--------------------------------\n"
  @league_limit 30
  @name_width 12
  @fame_width 9

  @doc "从 `conn.private[:fame_board]` 取数据源；未注入时返回空 map（走真实数据源）"
  def sources(conn) do
    case Map.get(conn.private, :fame_board) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  @doc "渲染整块榜单文本"
  def render(category, sources \\ %{}) do
    arg =
      category
      |> to_string()
      |> String.trim()

    cond do
      arg in ["", "family"] -> family_board(source_for(sources, :family))
      arg == "league" -> league_board(source_for(sources, :league))
      true -> "你要看什么排行榜？\n"
    end
  end

  # ---- 两个榜单 ----

  defp family_board(%{current: current, last: last}) do
    rows = rank(current)

    "目前江湖上所有名门大派的声望状况\n" <>
      @separator <>
      render_rows(rows, last) <>
      @separator <>
      "一共是#{ChineseNumber.to_chinese(length(rows))}个门派。\n"
  end

  defp league_board(%{current: current, last: last}) do
    case rank(current) do
      [] ->
        "目前江湖上没有什么有名的结义同盟。\n"

      all_rows ->
        rows = Enum.take(all_rows, @league_limit)

        "目前江湖上著名结义同盟的声望状况\n" <>
          @separator <>
          render_rows(rows, last) <>
          @separator <>
          "列出了#{ChineseNumber.to_chinese(length(rows))}个结义同盟。\n"
    end
  end

  # ---- 数据源 ----

  defp source_for(sources, kind) do
    case Map.get(sources, kind) do
      %{current: current, last: last} ->
        %{current: normalize(current), last: normalize(last)}

      _ ->
        default_source(kind)
    end
  end

  defp default_source(:family) do
    %{current: normalize(FamilyFame.all()), last: normalize(FamilyFame.last())}
  end

  defp default_source(:league) do
    %{
      current:
        League.ranking()
        |> Enum.map(fn league -> {league.fname, fame_of(league.fame)} end)
        |> Map.new(),
      last: normalize(League.query_all_last_league_fame())
    }
  rescue
    # 进程树未启动时 League.ranking/0 直读 ETS 会抛 ArgumentError；
    # 此时按「空同盟榜」处理，命令不应崩。
    _ -> %{current: %{}, last: %{}}
  end

  defp normalize(map) when is_map(map) do
    map
    |> Enum.reject(fn {name, _fame} -> is_nil(name) or name == 0 end)
    |> Map.new(fn {name, fame} -> {to_string(name), fame_of(fame)} end)
  end

  defp normalize(_), do: %{}

  defp fame_of(value) when is_integer(value), do: value
  defp fame_of(_), do: 0

  # ---- 排序 / 行渲染 ----

  defp rank(current) do
    current
    |> Enum.sort_by(fn {name, fame} -> {-fame, name} end)
  end

  defp render_rows(rows, last) do
    rows
    |> Enum.with_index(1)
    |> Enum.map_join("", fn {{name, fame}, index} ->
      delta = fame - Map.get(last, name, fame)

      "#{String.pad_leading(to_string(index), 2)}. " <>
        "#{pad_name(name)}  " <>
        "#{String.pad_trailing(to_string(fame), @fame_width)}" <>
        "(#{delta_text(delta)})\n"
    end)
  end

  defp delta_text(delta) when delta > 0, do: "+" <> to_string(delta)
  defp delta_text(delta), do: to_string(delta)

  defp pad_name(name) do
    text = to_string(name)
    text <> String.duplicate(" ", max(@name_width - columns(text), 0))
  end

  # 终端显示列宽：CJK 统一按 2 列算（LPC 是按字节，见 moduledoc 差异 2）
  defp columns(text) do
    text
    |> String.to_charlist()
    |> Enum.reduce(0, fn cp, acc -> acc + char_columns(cp) end)
  end

  defp char_columns(cp) do
    cond do
      cp in 0x1100..0x115F -> 2
      cp in 0x2E80..0xA4CF -> 2
      cp in 0xAC00..0xD7A3 -> 2
      cp in 0xF900..0xFAFF -> 2
      cp in 0xFE10..0xFE6F -> 2
      cp in 0xFF00..0xFF60 -> 2
      cp in 0xFFE0..0xFFE6 -> 2
      true -> 1
    end
  end
end

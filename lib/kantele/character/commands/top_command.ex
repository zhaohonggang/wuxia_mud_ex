defmodule Kantele.Character.TopCommand do
  @moduledoc """
  排行榜命令：`top [exp|lv|hp|qi|jing|neili|jingli|age|kill|die|league]`

  对应 LPC `cmds/usr/top.c`。LPC 的流程是：15 秒浏览节流 → 类别白名单 →
  `CACHE_D->get(arg)` → 渲染英雄榜 → `set_temp("last_view", time())` →
  告知玩家自己的名次。本端口逐条落地：

  - **类别别名**：`lv`/`exp` 都归到 `combat_exp`（标题「经验等级」），
    `hp` 归到 `qi`（「气 血 值」）——与 LPC 的两次 `arg` 改写一致；
  - **数据源**：`Kantele.Character.TopRanking`（`CACHE_D` 等价物），
    落盘字段查全服，运行态气血/精力查在线玩家，`kill/die` 因本服未记录
    计数器而给出明确提示；
  - **节流**：`meta.temp["last_view"]` + `System.system_time(:second)`，
    15 秒内重复查看返回「排行榜更新中……请稍侯片刻。」；wizard 绕过；
  - **英雄榜**：与 LPC 同款框线/表头/空榜行，末尾报出自己名次。

  `league` 是本端口原有的扩展（LPC `top.c` 没有此项），仍走
  `Kantele.League.ranking/0`，不套 15 秒节流，保持既有行为。

  单测可向 `conn.private` 注入 `:top_ranking`（一个 `category -> result` 的函数）
  与 `:top_now`（整数秒），避免依赖数据库与真实时钟。注意 `conn.private` 是
  `Kalevala.Character.Conn.Private` 结构体、未实现 `Access`，读写一律用
  `Map.get/2` / `Map.put/3`，不能用 `private[:key]`。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.TopRanking
  alias Kantele.League

  @throttle_seconds 15

  @help "目前只提供等级(top lv)/经验(top exp)/气血(top hp)/年龄(top age)/杀敌(top kill)/帮派(top league)等全服排行。\n"

  def run(conn, %{"category" => category}) when is_binary(category) do
    case category do
      "league" ->
        render_text(conn, league_ranking())

      _ ->
        if TopRanking.supported?(category) do
          show_ranking(conn, category)
        else
          render_text(conn, @help)
        end
    end
  end

  def run(conn, _params), do: render_text(conn, @help)

  defp show_ranking(conn, category) do
    if throttled?(conn) do
      render_text(conn, "\n排行榜更新中……请稍侯片刻。\n")
    else
      source = ranking_source(conn)

      case source.(category) do
        :unsupported ->
          render_text(conn, "本服尚未记录『#{TopRanking.title(category)}』数据，无法生成排行。\n")

        :error ->
          render_text(conn, "排行榜暂时无法读取，请稍后再试。\n")

        %{title: title, rows: rows} = result ->
          text = board(title, rows, conn.character, Map.get(result, :online_only?, false))

          conn
          |> put_character(remember_view(conn.character))
          |> render(CommandView, "text", %{text: text})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  # ---- 英雄榜渲染（对齐 top.c 的框线布局，去掉 ANSI 转义，由客户端自行着色） ----

  defp board(title, rows, me, online_only?) do
    note = if online_only?, do: "（在线玩家）", else: ""

    header =
      "\n                 ┏----『 英 雄 榜 』----┓\n" <>
        "┏-------------------------------------------------------┓\n" <>
        "┃ 排 行 | 姓    名 |     称          号    |  #{title}#{note}  ┃\n" <>
        "┠-------------------------------------------------------┨\n"

    body =
      case rows do
        [] ->
          "┃        暂时空缺           无                -  ┃\n"

        rows ->
          rows
          |> Enum.with_index(1)
          |> Enum.map_join("", fn {row, i} ->
            name = String.pad_trailing(row.name, 12)
            title_text = String.pad_trailing(row.title, 20)
            value = row.value |> to_string() |> String.pad_leading(12)

            "┃  #{String.pad_trailing(to_string(i), 5)} #{name}#{title_text} #{value}  ┃\n"
          end)
      end

    footer = "┠-------------------------------------------------------┨\n"

    index =
      case Enum.find_index(rows, &(&1.name == me.name)) do
        nil -> 0
        i -> i + 1
      end

    header <> body <> footer <> "\n提示：你的『#{title}』在全服排行第 #{index} 位。\n"
  end

  # ---- 15 秒节流（LPC query_temp("last_view") / set_temp） ----

  defp throttled?(conn) do
    character = conn.character

    if wizard?(character) do
      false
    else
      now = now(conn)
      last = last_view(character)
      is_integer(last) and now - last < @throttle_seconds
    end
  end

  defp wizard?(character) do
    env = Map.get(character.meta || %{}, :env) || %{}

    Map.get(character, :wiz_level, 0) not in [nil, 0, ""] or
      Map.get(env, "wizard") == true or Map.get(env, :wizard) == true
  end

  defp last_view(character) do
    temp = Map.get(character.meta || %{}, :temp) || %{}
    Map.get(temp, "last_view") || Map.get(temp, :last_view)
  end

  defp remember_view(character) do
    meta = character.meta || %{}
    temp = Map.get(meta, :temp) || %{}
    new_meta = Map.put(meta, :temp, Map.put(temp, "last_view", System.system_time(:second)))
    %{character | meta: new_meta}
  end

  defp now(conn) do
    case Map.get(conn.private, :top_now) do
      value when is_integer(value) -> value
      _ -> System.system_time(:second)
    end
  end

  # 默认走真实数据源；单测注入同签名函数即可。
  defp ranking_source(conn) do
    case Map.get(conn.private, :top_ranking) do
      fun when is_function(fun, 1) -> fun
      _ -> &TopRanking.ranking/1
    end
  end

  # ---- 输出 ----

  defp render_text(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp league_ranking do
    League.ranking()
    |> Enum.with_index(1)
    |> Enum.map_join("", fn {league, i} ->
      "  #{i}. 「#{league.fname}」  威望 #{league.fame}  成员 #{length(league.member)}\n"
    end)
    |> case do
      "" -> "江湖上还没有任何结义同盟。\n"
      msg -> "结义同盟声望排行：\n#{msg}"
    end
  end
end

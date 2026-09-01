defmodule Kantele.Character.NewsCommand do
  @moduledoc """
  新闻命令：`news [<编号>|new|all] | search <title|author|document> <关键词> | post <标题> | discard <编号>`

  对应 LPC cmds/usr/news.c。
  游戏新闻系统：阅读、发布、删除、搜索新闻。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.NewsService

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    # 3秒冷却
    if check_cooldown(conn) do
      conn
      |> render(CommandView, "text", %{text: "系统气喘嘘地叹道：慢慢来 ....\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case arg do
        "" ->
          show_news_list(conn, false)

        "new" ->
          show_news_new(conn)

        "all" ->
          show_news_list(conn, true)

        "discard " <> rest ->
          id_str = String.trim(rest)
          case Integer.parse(id_str) do
            {id, _} -> discard_news(conn, id)
            :error -> show_news_help(conn)
          end

        "del " <> rest ->
          id_str = String.trim(rest)
          case Integer.parse(id_str) do
            {id, _} -> discard_news(conn, id)
            :error -> show_news_help(conn)
          end

        "post " <> rest ->
          title = String.trim(rest)
          post_news(conn, title)

        "add " <> rest ->
          title = String.trim(rest)
          post_news(conn, title)

        "search " <> rest ->
          search_str = String.trim(rest)
          case Regex.run(~r/^(title|author|document)\s+(.+)$/, rest) do
            [_full, field, keyword] ->
              search_news(conn, field, keyword)
            _ ->
              show_news_help(conn)
          end

        "find " <> rest ->
          search_str = String.trim(rest)
          case Regex.run(~r/^(title|author|document)\s+(.+)$/, rest) do
            [_full, field, keyword] ->
              search_news(conn, field, keyword)
            _ ->
              show_news_help(conn)
          end

        _ ->
          # 尝试解析为数字
          case Integer.parse(arg) do
            {n, _} -> show_news_number(conn, n)
            :error -> show_news_help(conn)
          end
      end
    end
  end

  def run(conn, %{}) do
    show_news_list(conn, false)
  end

  defp check_cooldown(conn) do
    last_news = conn.character.meta.temp["last_news"] || 0
    now = :os.system_time(:second)

    if now - last_news < 3 do
      true
    else
      new_temp = Map.put(conn.character.meta.temp, "last_news", now)
      new_meta = Map.put(conn.character.meta, :temp, new_temp)
      new_character = %{conn.character | meta: new_meta}
      put_character(conn, new_character)
      false
    end
  end

  defp show_news_list(conn, show_all) do
    case NewsService.show_news(show_all) do
      news_list when is_list(news_list) and news_list != [] ->
        msg = build_news_list_msg(news_list)
        conn
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})


      _ ->
        conn
        |> render(CommandView, "text", %{text: "目前没有任何新闻。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_news_new(conn) do
    case NewsService.show_news(false) do
      [latest | _] ->
        show_news_detail(conn, latest)
      _ ->
        conn
        |> render(CommandView, "text", %{text: "暂无最新新闻。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_news_number(conn, id) do
    case NewsService.read_news(id) do
      {:ok, news} ->
        show_news_detail(conn, news)
      {:error, reason} ->
        conn
        |> render(CommandView, "text", %{text: reason <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_news_detail(conn, news) do
    time_str = DateTime.from_unix!(news.time) |> DateTime.to_string("Y年m月d日 H时M分")

    msg = """
    [#{news.id}] #{news.title}
    作者：#{news.author_name}(#{news.author_id})
    时间：#{time_str}
    ------------------------------------------------------------
    #{news.content}
    """

    conn
    |> render(CommandView, "text", %{text: msg})
    |> prompt(CommandView, "prompt", %{})
  end

  defp post_news(conn, title) do
    # 简化：实际应进入编辑器输入内容
    character = conn.character
    is_wizard = character.attributes["wiz_level"] && character.attributes["wiz_level"] > 0

    if !is_wizard do
      conn
      |> render(CommandView, "text", %{text: "你尚无权力发布新闻。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
      |> render(CommandView, "text", %{text: "新闻发布功能待完善（需编辑器支持）。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp discard_news(conn, id) do
    character = conn.character
    is_wizard = character.attributes["wiz_level"] && character.attributes["wiz_level"] > 0

    if !is_wizard do
      conn
      |> render(CommandView, "text", %{text: "你尚无权力删除新闻。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case NewsService.do_discard(character.id, id) do
        :ok ->
          conn
          |> render(CommandView, "text", %{text: "新闻已删除。\n"})
          |> prompt(CommandView, "prompt", %{})


        {:error, reason} ->
          conn
          |> render(CommandView, "text", %{text: reason <> "\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp search_news(conn, field, keyword) do
    case NewsService.do_search(field, keyword) do
      results when is_list(results) and results != [] ->
        msg = Enum.with_index(results, 1)
        |> Enum.map(fn {n, i} ->
          time_str = DateTime.from_unix!(n.time) |> DateTime.to_string("m-d H:M")
          "[#{n.id}] #{n.title}  #{n.author_name}  #{time_str}"
        end)
        |> Enum.join("\n")

        conn
        |> render(CommandView, "text", %{text: "搜索结果：\n#{msg}\n"})
        |> prompt(CommandView, "prompt", %{})


      _ ->
        conn
        |> render(CommandView, "text", %{text: "没有找到符合条件的新闻。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_news_help(conn) do
    conn
    |> render(CommandView, "text", %{
      text: """
      指令格式：
        news [<编号>|new|all]           - 阅读新闻
        news search <title|author|document> <关键词> - 搜索新闻
        news post <标题>                - 发布新闻 (巫师)
        news discard <编号>             - 删除新闻 (巫师)
      """
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp build_news_list_msg(news_list) do
    header = "游戏新闻：\n" <> String.duplicate("-", 60) <> "\n"

    list = Enum.with_index(news_list, 1)
    |> Enum.map(fn {n, i} ->
      time_str = DateTime.from_unix!(n.time) |> DateTime.to_string("m-d H:M")
      "[#{n.id}] #{n.title}  #{n.author_name}  #{time_str}"
    end)
    |> Enum.join("\n")

    header <> list <> "\n"
  end
end
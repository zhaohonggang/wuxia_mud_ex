defmodule Kantele.Character.WenxuanCommand do
  @moduledoc """
  文选命令：`wenxuan [new|<年份> [编号]] | add <编号> from <留言板> | del <年份> <编号>`

  对应 LPC cmds/std/wenxuan.c。
  文选系统：阅读、添加、删除、转换文章选集。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.AnalectaService

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    cond do
      arg == "" ->
        show_wenxuan_list(conn)

      arg == "new" ->
        show_wenxuan_new(conn, :os.system_time(:second) |> DateTime.from_unix!() |> DateTime.to_date() |> Map.get(:year))

      String.starts_with?(arg, "new ") ->
        year = String.trim(String.slice(arg, 4..-1)) |> String.to_integer()
        show_wenxuan_new(conn, year)

      String.starts_with?(arg, "add ") ->
        # 解析: add <编号> from <留言板>
        case Regex.run(~r/^add\s+(\d+)\s+from\s+(.+)$/, arg) do
          [_full, idx, board_name] ->
            add_from_board(conn, String.to_integer(idx), board_name)
          _ ->
            show_wenxuan_help(conn)
        end

      String.starts_with?(arg, "del ") ->
        # 解析: del <年份> <编号>
        case Regex.run(~r/^del\s+(\d+)\s+(\d+)$/, arg) do
          [_full, year, idx] ->
            delete_analecta(conn, String.to_integer(year), String.to_integer(idx))
          _ ->
            show_wenxuan_help(conn)
        end

      # 尝试解析为年份或 年份 编号
      true ->
        case Regex.run(~r/^(\d+)(?:\s+(\d+))?$/, arg) do
          [_full, year_str, idx_str] ->
            year = String.to_integer(year_str)

            if idx_str do
              read_analecta(conn, year, String.to_integer(idx_str))
            else
              show_wenxuan_year(conn, year)
            end

          _ ->
            show_wenxuan_help(conn)
        end
    end
  end

  def run(conn, %{}) do
    show_wenxuan_list(conn)
  end

  defp show_wenxuan_list(conn) do
    year = :os.system_time(:second) |> DateTime.from_unix!() |> DateTime.to_date() |> Map.get(:year)

    case AnalectaService.query_analecta_list(year) do
      analectas when is_list(analectas) and analectas != [] ->
        msg = build_list_msg(analectas, year)
        conn
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})


      _ ->
        conn
        |> render(CommandView, "text", %{text: "现在 #{year} 年没有任何文选供你阅读。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_wenxuan_year(conn, year) do
    case AnalectaService.query_analecta_list(year) do
      analectas when is_list(analectas) and analectas != [] ->
        msg = build_list_msg(analectas, year)
        conn
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})


      _ ->
        conn
        |> render(CommandView, "text", %{text: "现在 #{year} 年没有任何文选供你阅读。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_wenxuan_new(conn, year) do
    case AnalectaService.query_analecta_list(year) do
      analectas when is_list(analectas) and analectas != [] ->
        # 按时间倒序，取最新一篇
        analecta = List.first(analectas)
        case AnalectaService.get_analecta(year, analecta.id) do
          {:ok, analecta} ->
            show_analecta(conn, analecta, year, 1)
          _ ->
            conn
            |> render(CommandView, "text", %{text: "获取文选失败。\n"})
            |> prompt(CommandView, "prompt", %{})
        end

      _ ->
        conn
        |> render(CommandView, "text", %{text: "现在 #{year} 没有任何新的文选供你阅读。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp read_analecta(conn, year, index) do
    case AnalectaService.get_analecta(year, index) do
      {:ok, analecta} ->
        show_analecta(conn, analecta, year, index)
      {:error, reason} ->
        conn
        |> render(CommandView, "text", %{text: reason <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp show_analecta(conn, analecta, year, index) do
    time_str = DateTime.from_unix!(analecta.time) |> DateTime.to_string("Y年m月d日 H时M分")

    msg = """
    #{analecta.subject}
    作者：#{analecta.author_name}(#{analecta.author_id})
    时间：#{time_str}
    来源：#{analecta.board}
    ------------------------------------------------------------
    #{analecta.content}
    """

    conn
    |> render(CommandView, "text", %{text: msg})
    |> prompt(CommandView, "prompt", %{})
  end

  defp add_from_board(conn, note_index, board_name) do
    # 简化：实际应从留言板获取留言
    conn
    |> render(CommandView, "text", %{text: "从留言板添加文选功能待完善（需巫师权限）。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp delete_analecta(conn, year, index) do
    # 仅巫师可删，简化处理
    conn
    |> render(CommandView, "text", %{text: "删除文选功能需要巫师权限。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp build_list_msg(analectas, year) do
    header = "江湖文选 #{year} 年度选集：\n" <> String.duplicate("=", 60) <> "\n"

    list = Enum.with_index(analectas, 1)
    |> Enum.map(fn {a, i} ->
      time_str = DateTime.from_unix!(a.time) |> DateTime.to_string("m-d H:M")
      "#{i}. #{a.subject}  [#{a.author_name}]  #{time_str}  [#{a.board}]"
    end)
    |> Enum.join("\n")

    header <> list <> "\n"
  end

  defp show_wenxuan_help(conn) do
    conn
    |> render(CommandView, "text", %{
      text: """
      指令格式：
        wenxuan                    - 列出当年文选
        wenxuan <年份>             - 列出指定年份文选
        wenxuan <年份> <编号>      - 阅读指定文选
        wenxuan new                - 阅读最新文选
        wenxuan new <年份>         - 阅读指定年份最新文选
        wenxuan add <编号> from <留言板> - 从留言板添加文选 (巫师)
        wenxuan del <年份> <编号>  - 删除文选 (巫师)
      """
    })
    |> prompt(CommandView, "prompt", %{})
  end
end
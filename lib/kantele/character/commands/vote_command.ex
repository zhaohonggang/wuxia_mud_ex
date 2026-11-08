defmodule Kantele.Character.VoteCommand do
  @moduledoc """
  投票命令：`vote`

  对应 LPC `cmds/std/vote.c`。
  投票系统。

  用法：
  - `vote`：显示当前全部进行中的投票动议
  - `vote chblk <某人>`：发起/附议「关闭频道」动议
  - `vote unchblk <某人>`：发起/附议「打开频道」动议

  依赖 `Kantele.Character.Vote` daemon（Vote_D）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Vote

  @acts ~w[chblk unchblk]

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    rest = String.trim(rest)

    case String.split(rest, " ") do
      [act, victim] when act in @acts ->
        Vote.ensure!()
        handle_vote(conn, act, String.trim(victim))

      _ ->
        show_help(conn)
    end
  end

  def run(conn, %{"command" => "vote"}) do
    Vote.ensure!()
    show_status(conn)
  end

  def run(conn, %{}) do
    Vote.ensure!()
    show_status(conn)
  end

  # ---- 显示动议列表 ----

  defp show_status(conn) do
    votes = Vote.query_all_votes()

    vote_list =
      if length(votes) > 0 do
        Enum.join(Enum.map(votes, fn v ->
          "  #{v.id}: #{v.act} #{v.victim}（发起人：#{v.initiator_name}，#{map_size(v.voters)} 票）"
        end), "\n")
      else
        "  （暂无进行中的投票动议）"
      end

    conn
    |> render(CommandView, "text", %{
      text: "=== 投票动议列表 ===\n#{vote_list}\n====================\n用法：vote chblk <某人> | vote unchblk <某人>\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 处理投票 ----

  defp handle_vote(conn, act, victim) do
    character = conn.character

    case Vote.create_vote(character, act, victim) do
      {:ok, vote_id} ->
        render_created(conn, act, victim, vote_id)

      {:error, :already_active, vote_id} ->
        case Vote.cast_vote(character, vote_id) do
          {:ok, :voted} ->
            render_voted(conn)

          {:error, :already_voted} ->
            render_already_voted(conn)

          {:error, :initiator_vote} ->
            render_initiator_vote(conn)

          _ ->
            render_error(conn, "无法对该动议附议。")
        end

      {:error, :invalid_act} ->
        render_error(conn, "不支持的动议类型：#{act}，可用：chblk、unchblk。")

      {:error, reason} ->
        render_error(conn, "发起投票失败：#{inspect(reason)}。")
    end
  end

  # ---- 渲染 ----

  defp render_created(conn, act, victim, _vote_id) do
    act_text = case act do
      "chblk" -> "关闭频道"
      "unchblk" -> "打开频道"
      _ -> act
    end

    conn
    |> render(CommandView, "text", %{
      text: "你发起了 #{act_text} #{victim} 的投票动议，等待其他玩家附议。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp render_voted(conn) do
    conn
    |> render(CommandView, "text", %{text: "你已对该动议附议。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp render_already_voted(conn) do
    conn
    |> render(CommandView, "text", %{text: "你已经对该动议投过票了。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp render_initiator_vote(conn) do
    conn
    |> render(CommandView, "text", %{text: "作为发起人，你无需对自己的动议附议。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp show_help(conn) do
    conn
    |> render(CommandView, "text", %{text: "用法：vote | vote chblk <某人> | vote unchblk <某人>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp render_error(conn, msg) do
    conn
    |> render(CommandView, "text", %{text: "#{msg}\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

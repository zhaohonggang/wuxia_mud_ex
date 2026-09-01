defmodule Kantele.Character.TopCommand do
  @moduledoc """
  排行榜命令：`top [exp|lv|qi|age|kill|die]`

  对应 LPC cmds/usr/top.c
  显示各项排行榜。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.League

  def run(conn, %{"category" => category}) do
    msg =
      case category do
        "exp" -> "排行榜暂未开放。\n"
        "lv" -> "排行榜暂未开放。\n"
        "qi" -> "排行榜暂未开放。\n"
        "age" -> "排行榜暂未开放。\n"
        "kill" -> "排行榜暂未开放。\n"
        "die" -> "排行榜暂未开放。\n"
        "league" -> league_ranking()
        _ -> "目前只提供等级(top lv)/经验(top exp)/气血(top hp)/年龄(top age)/杀敌(top kill)/帮派(top league)等全服排行。\n"
      end

    conn
    |> render(CommandView, "text", %{text: msg})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{
      text: "目前只提供等级(top lv)/经验(top exp)/气血(top hp)/年龄(top age)/杀敌(top kill)等全服排行。\n"
    })
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

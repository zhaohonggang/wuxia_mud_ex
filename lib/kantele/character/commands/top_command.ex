defmodule Kantele.Character.TopCommand do
  @moduledoc """
  排行榜命令：`top [exp|lv|qi|age|kill|die]`

  对应 LPC cmds/usr/top.c
  显示各项排行榜。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"category" => category}) do
    msg =
      case category do
        "exp" -> "排行榜暂未开放。\n"
        "lv" -> "排行榜暂未开放。\n"
        "qi" -> "排行榜暂未开放。\n"
        "age" -> "排行榜暂未开放。\n"
        "kill" -> "排行榜暂未开放。\n"
        "die" -> "排行榜暂未开放。\n"
        _ -> "目前只提供等级(top lv)/经验(top exp)/气血(top hp)/年龄(top age)/杀敌(top kill)等全服排行。\n"
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
end

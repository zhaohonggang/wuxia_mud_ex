defmodule Kantele.Character.Top2Command do
  @moduledoc """
  门派 / 结义同盟声望榜：`top2 [family | league]`

  对应 LPC `cmds/usr/top2.c`。裸 `top2` 与 `top2 family` 同义（门派榜），
  `top2 league` 出同盟榜，其它参数回 `你要看什么排行榜？`。

  渲染逻辑与 `Kantele.Character.ToppCommand` 共用
  `Kantele.Character.FameBoard` —— LPC 的 `top2.c` 与 `topp.c` 是两份内容
  完全相同的源码，Ex 侧不再复制一遍。

  单测可向 `conn.private` 注入 `:fame_board` 覆盖真实数据源，详见
  `FameBoard` 的 moduledoc。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.FameBoard

  def run(conn, params) do
    text = FameBoard.render(Map.get(params, "category", ""), FameBoard.sources(conn))

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

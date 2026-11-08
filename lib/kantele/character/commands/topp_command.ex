defmodule Kantele.Character.ToppCommand do
  @moduledoc """
  门派 / 结义同盟声望榜：`topp [family | league]`

  对应 LPC `cmds/usr/topp.c`。该文件与 `top2.c` 逐行相同（连 help 文本都写着
  `top [family | league]`），是 LPC 侧历史遗留的重复命令；Ex 保留独立动词以兼容
  玩家习惯，但与 `Kantele.Character.Top2Command` 共用
  `Kantele.Character.FameBoard` 的渲染与数据源，保证两条命令输出永远一致。
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

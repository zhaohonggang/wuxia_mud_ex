defmodule Kantele.Character.Score2Command do
  @moduledoc """
  详细分数命令：`score2`

  对应 LPC cmds/usr/score2.c
  显示详细角色信息。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    stats = character.meta.stats
    vitals = character.meta.vitals

    info = """
    【 姓名 】#{character.name}
    【 经验 】#{stats.combat_exp}
    【 潜能 】#{stats.potential}
    【 门派 】#{inspect(character.meta.family)}
    """

    conn
    |> render(CommandView, "text", %{text: info})
    |> prompt(CommandView, "prompt", %{})
  end
end

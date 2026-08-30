defmodule Kantele.Character.HpCommand do
  @moduledoc """
  状态命令：`hp`

  对应 LPC cmds/usr/hp.c
  显示角色状态。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, _params) do
    character = conn.character
    vitals = character.meta.vitals

    info = """
    【 气血 】 #{vitals.qi}/#{vitals.max_qi}
    【 精气 】 #{vitals.jing}/#{vitals.max_jing}
    【 内力 】 #{vitals.neili}/#{vitals.max_neili}
    【 精力 】 #{vitals.jingli}/#{vitals.max_jingli}
    """

    conn
    |> render(CommandView, "text", %{text: info})
    |> prompt(CommandView, "prompt", %{})
  end
end

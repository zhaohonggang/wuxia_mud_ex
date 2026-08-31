defmodule Kantele.Character.AssistEvent do
  @moduledoc """
  协助请求事件处理：收到 assist/request 后存储待处理请求并提示玩家
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView

  def request(conn, %{data: %{from_id: from_id, from_name: from_name}}) do
    # 存储待处理协助请求
    meta =
      Map.put(conn.character.meta, :temp, Map.put(conn.character.meta.temp || %{}, "pending_assist_request", %{
        id: from_id,
        name: from_name
      }))

    character = %{conn.character | meta: meta}

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{
      text: "#{from_name} 请求协助你完成任务，是否接受？(assist accept / assist refuse)\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end
end

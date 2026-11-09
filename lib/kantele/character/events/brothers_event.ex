defmodule Kantele.Character.BrothersEvent do
  @moduledoc """
  断义事件处理：收到兄弟的断义通知，把对方从自己内存结义名单移除并提示。

  - `brothers/broken`：从 brothers 列表移除 breaker_id 并提示「X 与你断绝了关系」
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def broken(conn, %{data: %{breaker_id: breaker_id, breaker_name: breaker_name}}) do
    character = conn.character

    remaining = Enum.reject(PlayerMeta.brothers(character.meta), &(&1.id == breaker_id))

    meta = PlayerMeta.put_brothers(character.meta, remaining)
    new_conn = put_character(conn, %{character | meta: meta})

    new_conn
    |> render(CommandView, "text", %{text: "#{breaker_name}与你断绝了关系。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end

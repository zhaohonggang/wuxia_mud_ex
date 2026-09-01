defmodule Kantele.Character.SwearEvent do
  @moduledoc """
  结拜事件处理：

  - `swear/request`（被邀方）：收到请求，记录 pending/answer 并提示 right/refuse 回应
  - `swear/pending`（请求方）：记录自己 pending/swear 的请求目标
  - `swear/joined`（双方）：把对方写入结义列表并清理待处理状态
  - `swear/cancelled`（被邀方）：对方取消请求，清理待处理状态
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def request(conn, %{data: %{from_id: from_id, from_name: from_name}}) do
    character = conn.character

    meta =
      character.meta
      |> PlayerMeta.put_temp("pending/swear_from_id", from_id)
      |> PlayerMeta.put_temp("pending/answer/#{from_id}", from_name)

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{
      text: "#{from_name}请求和你结拜，你答应(right #{from_name})还是不答应(refuse #{from_name})？\n"
    })
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def pending(conn, %{data: %{target_id: target_id, target_name: target_name}}) do
    character = conn.character

    meta =
      character.meta
      |> PlayerMeta.put_temp("pending/swear", target_name)
      |> PlayerMeta.put_temp("pending/swear_target_id", target_id)

    put_character(conn, %{character | meta: meta})
    |> save()
  end

  def joined(conn, %{data: %{partner_id: partner_id, partner_name: partner_name}}) do
    character = conn.character

    brothers =
      [%{id: partner_id, name: partner_name} | PlayerMeta.brothers(character.meta)]
      |> Enum.uniq_by(& &1.id)

    meta =
      character.meta
      |> PlayerMeta.put_brothers(brothers)
      |> PlayerMeta.delete_temp("pending/swear")
      |> PlayerMeta.delete_temp("pending/swear_target_id")
      |> PlayerMeta.delete_temp("pending/swear_from_id")
      |> PlayerMeta.delete_temp("pending/answer/#{partner_id}")

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "你和#{partner_name}结拜成异姓兄弟了！\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def cancelled(conn, %{data: %{from_id: from_id}}) do
    character = conn.character

    meta =
      character.meta
      |> PlayerMeta.delete_temp("pending/swear_from_id")
      |> PlayerMeta.delete_temp("pending/answer/#{from_id}")

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "对方打消了结拜的念头。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end
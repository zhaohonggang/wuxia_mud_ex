defmodule Kantele.Character.EngageEvent do
  @moduledoc """
  求婚/婚约事件处理（S3 engage/accede/divorce.c）

  - `engage/propose`（被求婚方）：记录 pending/engage_from_* / promise，提示用 accede <承诺> 应婚
  - `engage/pending`（求婚方）：记录自己 pending/engage 的请求目标与承诺
  - `engage/joined`（双方）：把对方写入 meta.spouse 并清理待处理状态
  - `engage/cancelled`（被求婚方）：对方取消，清理待处理状态
  - `engage/divorced`（被离婚方）：对方离婚，清除自身 meta.spouse
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta

  def propose(conn, %{data: %{from_id: from_id, from_name: from_name, promise: promise}}) do
    character = conn.character

    meta =
      character.meta
      |> PlayerMeta.put_temp("pending/engage_from_id", from_id)
      |> PlayerMeta.put_temp("pending/engage_from_name", from_name)
      |> PlayerMeta.put_temp("pending/engage_promise", promise)

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{
      text:
        "#{from_name}向你求婚，承诺是：「#{promise}」。若你愿意，就用 accede #{promise} 来答应。\n"
    })
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def pending(conn, %{data: %{target_id: target_id, target_name: target_name, promise: promise}}) do
    character = conn.character

    meta =
      character.meta
      |> PlayerMeta.put_temp("pending/engage", target_name)
      |> PlayerMeta.put_temp("pending/engage_target_id", target_id)
      |> PlayerMeta.put_temp("pending/engage_promise", promise)

    put_character(conn, %{character | meta: meta})
    |> save()
  end

  def joined(conn, %{data: %{partner_id: partner_id, partner_name: partner_name}}) do
    character = conn.character
    own_name = character.name

    meta =
      character.meta
      |> PlayerMeta.put_spouse(%{id: partner_id, name: partner_name})
      |> PlayerMeta.delete_temp("pending/engage")
      |> PlayerMeta.delete_temp("pending/engage_target_id")
      |> PlayerMeta.delete_temp("pending/engage_from_id")
      |> PlayerMeta.delete_temp("pending/engage_from_name")
      |> PlayerMeta.delete_temp("pending/engage_promise")

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{
      text: "你和#{partner_name}私定终身，结为夫妻（#{own_name} 与 #{partner_name}，永结同心）！\n"
    })
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def cancelled(conn, %{data: %{from_id: from_id}}) do
    character = conn.character

    meta =
      character.meta
      |> PlayerMeta.delete_temp("pending/engage_from_id")
      |> PlayerMeta.delete_temp("pending/engage_from_name")
      |> PlayerMeta.delete_temp("pending/engage_promise")

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "对方打消了求婚的念头。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  def divorced(conn, %{data: %{}}) do
    character = conn.character
    meta = PlayerMeta.put_spouse(character.meta, nil)

    put_character(conn, %{character | meta: meta})
    |> render(CommandView, "text", %{text: "对方与你解除了婚约，从此各走各路。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end

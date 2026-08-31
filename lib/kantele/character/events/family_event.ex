defmodule Kantele.Character.FamilyEvent do
  @moduledoc """
  拜师结果处理（A11/N5 v0，玩家侧）

  NPC 应允后把门派/师父写入 meta.family 并落盘；拒绝则展示原因。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def result(conn, %{data: %{ok: true} = data}) do
    character = conn.character
    family = %{name: data.family, master_id: data.master_id, master_name: data.master_name}
    character = Map.put(character, :meta, Map.put(character.meta, :family, family))

    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{
      text: "#{data.master_name}捋须点头：「好，从今日起你便是#{data.family}门下弟子，好生修炼，莫堕了师门名声。」\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, %{data: %{ok: false, reason: reason}}) do
    conn
    |> render(CommandView, "text", %{text: "#{reason}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, _event), do: conn
end

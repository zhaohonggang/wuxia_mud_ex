defmodule Kantele.Character.FamilyEvent do
  @moduledoc """
  拜师结果处理（A11/N5 v0，玩家侧）

  NPC 应允后**玩家侧**用 `SectMaster.recruit_gate?` 复核收徒门槛（shen/exp/
  心法），通过才写入 meta.family（含 class 继承）并落盘；门槛不过或 NPC 拒绝
  则展示原因（玩家侧校验）。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.SectMaster

  def result(conn, %{data: %{ok: true} = data}) do
    character = conn.character
    apprentice = Map.get(data, :apprentice)

    case SectMaster.recruit_gate?(nil, character, apprentice) do
      {:error, reason} ->
        conn
        |> render(CommandView, "text", %{text: "#{reason}\n"})
        |> prompt(CommandView, "prompt", %{})

      :ok ->
        family =
          %{name: data.family, master_id: data.master_id, master_name: data.master_name}
          |> put_class(apprentice)

        meta =
          character.meta
          |> Map.put(:family, family)
          |> Map.put(:stats, init_gongxian(character.meta.stats))

        character = %{character | meta: meta}
        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{
          text: "#{data.master_name}捋须点头：「好，从今日起你便是#{data.family}门下弟子，好生修炼，莫堕了师门名声。」\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def result(conn, %{data: %{ok: false, reason: reason}}) do
    conn
    |> render(CommandView, "text", %{text: "#{reason}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, _event), do: conn

  # class 继承（LPC: if ob->query("class") != "taoist" ob->set("class", "taoist")）；
  # bonze/eunach 不传播（对齐 Family.recruit_apprentice 的 class_propagate? 判据）
  defp put_class(family, %{class: class}) when class not in [nil, "bonze", "eunach"],
    do: Map.put(family, :class, class)

  defp put_class(family, _apprentice), do: family

  defp init_gongxian(%{gongxian: nil} = stats), do: %{stats | gongxian: 0}
  defp init_gongxian(stats), do: stats
end

defmodule Kantele.Character.FamilyEvent do
  @moduledoc """
  拜师结果处理（A11/N5 v0，玩家侧）

  NPC 应允后**玩家侧**用 `SectMaster.recruit_gate?` 复核收徒门槛（shen/exp/
  心法，以及少林达摩祖师的 11 项门槛），通过才写入 meta.family（含 class 继承）
  并落盘；门槛不过或 NPC 拒绝则展示原因（玩家侧校验）。

  ## 达摩祖师成功后的 LPC 行为（`kungfu/class/shaolin/da-mo.c`）

  `command("char 老衲又得一可塑之才，真是大畅老怀 !")` +
  `新法名 = "渡" + name[1..1]` + NAME_D 改名 + `command("say 从今以后你的法名叫做...")`
  + `command("recruit <id>")`。当 UCL apprentice 段带 `rename_prefix` /
  `rename_index` 时按此落地；`min_int < 阈值` 的**不 return** 语义由
  `recruit_gate?/3` 以 `{:ok, warning}` 返回，此处先显示提示再照常收徒。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias ExVenture.Characters
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.SectMaster
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  def result(conn, %{data: %{ok: true} = data}) do
    character = conn.character
    apprentice = Map.get(data, :apprentice) || %{}

    case SectMaster.recruit_gate?(nil, character, apprentice) do
      {:error, reason} -> reject(conn, reason)
      :ok -> accept(conn, character, data, apprentice, "")
      {:ok, warning} -> accept(conn, character, data, apprentice, warning)
    end
  end

  def result(conn, %{data: %{ok: false, reason: reason}}), do: reject(conn, reason)

  def result(conn, _event), do: conn

  defp reject(conn, reason) do
    conn
    |> render(CommandView, "text", %{text: "#{reason}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp accept(conn, character, data, apprentice, warning) do
    family =
      %{name: data.family, master_id: data.master_id, master_name: data.master_name}
      |> put_class(apprentice)
      |> put_generation(apprentice)

    meta =
      character.meta
      |> Map.put(:family, family)
      |> Map.put(:stats, init_gongxian(character.meta.stats))
      |> delete_promotion_flags(apprentice)

    character =
      character
      |> Map.put(:meta, meta)
      |> maybe_rename(apprentice, data)

    Records.save(character)

    conn =
      conn
      |> put_character(character)
      |> announce_tonsure(character, apprentice, data)

    text =
      warning <>
        "#{data.master_name}捋须点头：「好，从今日起你便是#{data.family}门下弟子，好生修炼，莫堕了师门名声。」\n"

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  # LPC `new_name = "渡" + name[1..1]`（rename_index=1 → 第二字，0-based grapheme）。
  # 与剃度一样：ex 无 NAME_D，改 DB 档案名走 rename_by_name/2。
  defp maybe_rename(character, apprentice, _data) do
    prefix = Map.get(apprentice, :rename_prefix)

    if is_binary(prefix) and byte_size(prefix) > 0 and is_binary(character.name) do
      index = Map.get(apprentice, :rename_index, 1)
      rest = character.name |> String.graphemes() |> Enum.at(index) || ""
      new_name = prefix <> rest

      if byte_size(new_name) > 0 do
        Characters.rename_by_name(character.name, new_name)
        %{character | name: new_name}
      else
        character
      end
    else
      character
    end
  end

  # LPC `command("char ...")` / `command("say 从今以后你的法名叫做...")`。
  # ex 无 NPC `char` 频道，按房间 vision 广播落地（文案逐字保留）。
  defp announce_tonsure(conn, character, apprentice, data) do
    room_id = character.room_id
    rename_prefix = Map.get(apprentice, :rename_prefix)

    if is_binary(rename_prefix) and byte_size(rename_prefix) > 0 and is_binary(room_id) do
      master = data.master_name

      conn
      |> RoomHelpers.broadcast_vision(
        room_id,
        "#{master}大笑道：老衲又得一可塑之才，真是大畅老怀 !\n"
      )
      |> RoomHelpers.broadcast_vision(
        room_id,
        "#{master}说道：从今以后你的法名叫做#{character.name}。\n"
      )
    else
      conn
    end
  end

  # class 继承（LPC: if ob->query("class") != "taoist" ob->set("class", "taoist")）；
  # bonze/eunach 不传播（对齐 Family.recruit_apprentice 的 class_propagate? 判据）
  defp put_class(family, %{class: class}) when class not in [nil, "bonze", "eunach"],
    do: Map.put(family, :class, class)

  defp put_class(family, _apprentice), do: family

  # LPC recruit_apprentice(): family["generation"] = my_family["generation"] + 1。
  # 只有 UCL 显式配置 master_generation 的师父才写，避免改变其它门派既有存档形状。
  defp put_generation(family, %{master_generation: master_gen}) when is_integer(master_gen),
    do: Map.put(family, :generation, master_gen + 1)

  defp put_generation(family, _apprentice), do: family

  # cheng/hui/dao/xuan/du.h 在越级收徒成功后 delete_temp("have_letter") /
  # delete_temp("apprentice_ok")。只在配置了 delete_flags_on_rename 时执行，
  # 与 rename_prefix 同批配置，避免误清其它门派的临时标记。
  defp delete_promotion_flags(meta, apprentice) do
    if Map.get(apprentice, :delete_flags_on_rename) == true do
      meta
      |> Kantele.Character.PlayerMeta.delete_temp("have_letter")
      |> Kantele.Character.PlayerMeta.delete_temp("apprentice_ok")
    else
      meta
    end
  end

  defp init_gongxian(%{gongxian: nil} = stats), do: %{stats | gongxian: 0}
  defp init_gongxian(stats), do: stats
end

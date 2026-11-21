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
  alias Kantele.Character, as: PlayerMeta
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.SectMaster
  alias Kantele.World.NameD
  alias Kantele.World.NpcActions.Helpers, as: NpcHelpers
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers
  alias Kantele.World.ShaolinApprenticeDialogue

  def result(conn, %{data: %{ok: true} = data}) do
    character = conn.character
    apprentice = Map.get(data, :apprentice) || %{}

    case SectMaster.recruit_gate?(nil, character, apprentice) do
      {:error, reason} ->
        reject(conn, reason)

      # #869 梅庄东方不败弟子：只写 move_party 标记，LPC 不收徒。
      {:defer, reason, mark} ->
        character = put_character_mark(character, mark)
        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: "#{reason}\n"})
        |> prompt(CommandView, "prompt", %{})

      # #869 黑白子/黄钟公：标记先落盘，但被 exp/技能门拒绝（LPC 原样）。
      {:error_with_mark, reason, mark} ->
        character = put_character_mark(character, mark)
        Records.save(character)
        conn = put_character(conn, character)
        reject(conn, reason)

      :ok ->
        accept(conn, character, data, apprentice, "")

      {:ok, warning} ->
        accept(conn, character, data, apprentice, warning)

      # #869 黑白子/黄钟公：先落 move_party 标记，再按常规门控收徒。
      {:ok_with_mark, warning, mark} ->
        character = put_character_mark(character, mark)
        Records.save(character)
        conn = put_character(conn, character)
        accept(conn, character, data, apprentice, warning)
    end
  end

  def result(conn, %{data: %{ok: false, reason: reason}}), do: reject(conn, reason)

  def result(conn, _event), do: conn

  defp reject(conn, reason) do
    reason =
      if is_binary(reason) do
        String.replace(reason, "%respect%", NpcHelpers.respect(conn.character))
      else
        reason
      end

    conn
    |> render(CommandView, "text", %{text: "#{reason}\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp accept(conn, character, data, apprentice, warning) do
    old_name = character.name
    student_generation = get_in(character.meta.family || %{}, [:generation])

    family =
      %{name: data.family, master_id: data.master_id, master_name: data.master_name}
      |> put_class(apprentice)
      |> put_generation(apprentice)

    meta =
      character.meta
      |> Map.put(:family, family)
      |> Map.put(:stats, init_gongxian(character.meta.stats))
      |> delete_promotion_flags(apprentice)
      |> delete_mark_on_accept(apprentice)

    character =
      character
      |> Map.put(:meta, meta)
      |> maybe_rename(apprentice, data)

    Records.save(character)

    conn =
      conn
      |> put_character(character)
      |> announce_tonsure(character, apprentice, data, student_generation, old_name)

    text =
      case Map.get(apprentice, :accept_msg) do
        msg when is_binary(msg) and byte_size(msg) > 0 ->
          custom =
            msg
            |> String.replace("%new_name%", character.name)
            # 昆仑 RANK_D->query_respect(me) 以显式占位落地；完整动态敬称见缺口 #758。
            |> String.replace("%respect%", NpcHelpers.respect(character))
            |> ensure_lf()

          warning <> custom

        _ ->
          warning <>
            "#{data.master_name}捋须点头：「好，从今日起你便是#{data.family}门下弟子，好生修炼，莫堕了师门名声。」\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  # #869 梅庄：黑白子/黄钟公收徒成功后 `delete("move_party/日月神教--梅庄")`。
  defp put_character_mark(character, mark) when is_binary(mark) and byte_size(mark) > 0 do
    %{character | meta: PlayerMeta.put_mark(character.meta, mark, 1)}
  end

  defp put_character_mark(character, _mark), do: character

  # #869 收徒成功后删除 move_party 标记；未配置该字段的门派完全不变。
  defp delete_mark_on_accept(meta, apprentice) do
    case {Map.get(apprentice, :delete_mark_on_accept), Map.get(apprentice, :defer_mark)} do
      {true, mark} when is_binary(mark) and byte_size(mark) > 0 ->
        %{meta | marks: Map.delete(meta.marks || %{}, mark)}

      _ ->
        meta
    end
  end

  # LPC `new_name = "渡" + name[1..1]`（rename_index=1 → 第二字，0-based grapheme）。
  # NAME-D 流程（LPC `NAME_D->remove_name/map_name` 等价）：
  #   1. NameD.remove_name(old_name, id)   释放旧名
  #   2. NameD.change_name(...) 检查新名是否冲突
  #   3. NameD.map_name(new_name, id)      登记新名
  #   4. Characters.rename_by_name/2       同步落盘 DB 档案名
  defp maybe_rename(character, apprentice, _data) do
    case {Map.get(apprentice, :rename_surname_from), Map.get(apprentice, :rename_surname_to)} do
      {from, to}
      when is_binary(from) and byte_size(from) > 0 and is_binary(to) and byte_size(to) > 0 ->
        maybe_rename_surname(character, from, to)

      _ ->
        maybe_rename_prefix(character, apprentice)
    end
  end

  # 原少林「法名 = 前缀 + 第 index 字」分支，保持既有行为不变。
  defp maybe_rename_prefix(character, apprentice) do
    prefix = Map.get(apprentice, :rename_prefix)

    if is_binary(prefix) and byte_size(prefix) > 0 and is_binary(character.name) do
      index = Map.get(apprentice, :rename_index, 1)
      rest = character.name |> String.graphemes() |> Enum.at(index) || ""
      new_name = prefix <> rest
      if byte_size(new_name) > 0, do: rename_character(character, new_name), else: character
    else
      character
    end
  end

  # #745 绝情谷 chi.c:132-145：仅当弟子姓「公孙」时改姓为「裘」并同步改名。
  # ex 无独立 purename 字段，以 env.surname + character.name 的前 N 个 grapheme
  # 等价还原 `purename`；NAME_D / DB 改名走与少林法名同一条管线。
  defp maybe_rename_surname(character, from, to) do
    name = character.name

    if is_binary(name) and String.starts_with?(name, from) do
      graphemes = String.graphemes(name)
      count = String.graphemes(from) |> length()

      if length(graphemes) > count and env_surname(character) == from do
        new_name = to <> (Enum.drop(graphemes, count) |> Enum.join())
        character = rename_character(character, new_name)
        meta = character.meta || %{}
        env = Map.get(meta, :env) || %{}
        %{character | meta: Map.put(meta, :env, Map.put(env, :surname, to))}
      else
        character
      end
    else
      character
    end
  end

  defp env_surname(character) do
    env = Map.get(character.meta || %{}, :env) || %{}
    Map.get(env, :surname) || Map.get(env, "surname")
  end

  # 1. 释放旧名 → 2. 查重 → 3. 登记新名 → 4. DB 落盘；失败一律保留旧名。
  defp rename_character(character, new_name) do
    NameD.ensure!()
    old_name = character.name
    NameD.remove_name(old_name, character.id)

    case NameD.change_name(old_name, character.id, new_name, false) do
      {:ok, _new_name} ->
        NameD.map_name(new_name, character.id)

        case Characters.rename_by_name(old_name, new_name) do
          {:ok, _} ->
            %{character | name: new_name}

          {:error, :not_found} ->
            Logger.warn("name_d: 旧名 #{old_name} 未在 DB 中找到，保留旧名")
            character

          {:error, :invalid} ->
            Logger.warn("name_d: 新名 #{new_name} 不合法或已被占用，保留旧名")
            character

          {:error, :db_unavailable} ->
            Logger.warn("name_d: DB 不可用，#{old_name} 未落盘")
            character
        end

      {:error, reason} ->
        Logger.warn("name_d: #{old_name} -> #{new_name} 被拒绝：#{reason}，保留旧名")
        character
    end
  end

  # LPC `command("char ...")` / `command("say ...")`：各字辈 attempt_apprentice 文案不同，
  # 由 ShaolinApprenticeDialogue 按分支选行；ex 无 NPC 社交频道，统一按房间 vision 广播。
  defp announce_tonsure(conn, character, apprentice, data, student_generation, old_name) do
    room_id = character.room_id

    if is_binary(room_id) do
      master = data.master_name

      ShaolinApprenticeDialogue.lines(
        apprentice,
        master,
        old_name,
        character.name,
        student_generation
      )
      |> Enum.reduce(conn, fn {channel, text}, acc ->
        verb = if channel == :char, do: "大笑道", else: "说道"

        RoomHelpers.broadcast_vision(
          acc,
          room_id,
          "#{master}#{verb}：#{ensure_lf(text)}"
        )
      end)
    else
      conn
    end
  end

  defp ensure_lf(text) when is_binary(text) do
    if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
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

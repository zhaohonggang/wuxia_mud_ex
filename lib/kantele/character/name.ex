defmodule Kantele.Character.Name do
  @moduledoc """
  名称/ID 纯逻辑（对应 `feature/name.c`）

  `my_id` 形如 `%{ids: [...], name: "某", id: "某0"}`。

  - `set_name/3`：name 为空时按 surname+purename 组名，缺省 `无名氏`；
    非玩家对象追加首字母小写 ID
  - `id?/2` / `parse_command_id_list/2`：ID 命中 / 取 applied id 列表（缺省 my_id）
  - `render_name/short`：名字 / 短名（name + (id)）
  """

  def set_name(base, name, ids) when is_binary(name) do
    name = if name == "", do: compose_name(base), else: name
    ids = normalize_ids(ids)
    %{my_id: ids, name: name, id: List.first(ids)}
  end

  @doc "surname+purename 组名；两者皆空则 `无名氏`"
  def compose_name(%{surname: s, purename: p}) do
    (to_str(s) <> to_str(p)) |> or_default("无名氏")
  end

  @doc "surname/purename 单字段组名"
  def compose_name(surname, purename) do
    (to_str(surname) <> to_str(purename)) |> or_default("无名氏")
  end

  @doc "id/str 命中（name.c id/1，忽略隐身判定）"
  def id?(%{my_id: ids}, str) when is_binary(str) do
    ids != nil && str in ids
  end

  @doc "parse_command_id_list：applied id 优先，缺省 my_id"
  def parse_command_id_list(%{my_id: ids}, applied_ids) do
    if is_list(applied_ids) and applied_ids != [], do: applied_ids, else: ids || []
  end

  @doc "渲染主名（name.c name/1；raw 时忽略 apply/name mask——此处名即主名）"
  def render_name(%{name: name}, raw \\ false) do
    if String.valid?(name) do
      name
    else
      if raw, do: name, else: "无名氏"
    end
  end

  @doc "短名：name + (id)（name.c short/1）"
  def render_short(obj) do
    name = obj.name

    id =
      if is_binary(obj.id) && obj.id != "", do: "(" <> String.capitalize(obj.id) <> ")", else: ""

    name <> id
  end

  @doc "非玩家对象追加首字母小写 ID"
  def lowercase_first(ids, is_player) do
    if is_player do
      ids
    else
      ids ++ [String.downcase(String.slice(ids |> List.first() || "", 0, 1))]
    end
  end

  defp normalize_ids(nil), do: nil
  defp normalize_ids(ids) when is_list(ids), do: ids

  defp to_str(nil), do: ""
  defp to_str(s) when is_binary(s), do: s

  defp or_default(s, default), do: if(s == "", do: default, else: s)
end

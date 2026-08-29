defmodule Kantele.Item.Cutable do
  @moduledoc """
  可切割尸体/物（对应 `feature/cutable.c`）

  纯逻辑躯壳，供宿主 do_cut 命令接入：

  - `available_parts/2`: 可割清单（"?" 列表），排除 already-cut 与 no_cut
  - `validate_cut/5`: 校验武器/内力，返回 `{:ok, msg}` 或 `{:error, msg}`
  - `extra_desc/2`: 已割部位摘要

  parts 约定（对照 cutable.c 的 8 字段数组）：
  `part = [level, unit, name, name_left, id_left, ass_part, verb, clone]`
  用 `part_name/1` 等读取。
  """

  @doc "是否可切割 (is_cutable)"
  def is_cutable?(_), do: true

  @doc "可割部位列表（排除已割与 no_cut）"
  def available_parts(parts, been_cut, no_cut \\ %{}) do
    parts
    |> Map.keys()
    |> Enum.reject(&excluded?(&1, been_cut, no_cut))
  end

  @doc "部位显示名（NAME，索引 2）"
  def part_name(part), do: Enum.at(part, 2)

  @doc """
  validate_cut（LPC do_cut 的武器/修为校验）

  opts: `%{part_id: id, part: part(map(nil)), been_cut: list, no_cut: map,
           weapon_skill_type: str|nil, weapon_name: str|nil,
           skill: %{per_skill_type => 等级}, force: int}`

  返回 `{:ok, msg_template}`（msg 含 $N/$n/部位 占位，宿主渲染）
  或 `{:error, msg}` / `{:error_force, part_name}`。
  """
  def validate_cut(part, opts) do
    %{been_cut: cut, no_cut: no_cut} = opts
    pid = Map.get(opts, :part_id)
    cut = cut || []

    cond do
      not is_list(part) ->
        {:error, "你怎么也找不到你想割的部位。"}

      pid in cut ->
        {:error, "#{part_name(part)}已经被割走了。"}

      Map.has_key?(no_cut, pid) ->
        msg = Map.get(no_cut, pid)
        {:error, if(is_binary(msg), do: msg, else: "这样东西你割不下来。")}

      true ->
        validate_weapon(part, opts)
    end
  end

  @doc "extra_desc：已割部位摘要（LPC extra_desc）"
  def extra_desc(parts, been_cut, main_part_level \\ 0) do
    kept =
      Enum.filter(been_cut || [], fn id ->
        part = Map.get(parts, id)
        is_list(part) && Enum.at(part, 0) <= main_part_level
      end)

    case kept do
      [] ->
        ""

      kept ->
        names = Enum.map_join(kept, "、", fn id -> part_name(Map.get(parts, id)) end)
        "不过它的" <> names <> "已经不见了。\n"
    end
  end

  # ---- internal ----

  defp excluded?(id, been_cut, no_cut) do
    (id in (been_cut || [])) or
      (Map.get(no_cut, id) != nil)
  end

  defp validate_weapon(part, opts) do
    skill_type = Map.get(opts, :weapon_skill_type)
    wname = Map.get(opts, :weapon_name)
    skill = Map.get(opts, :skill, %{})
    force = Map.get(opts, :force, 0)

    if skill_type do
      cond do
        skill_type == "pin" ->
          if Map.get(skill, "sword", 0) < 100 do
            {:error, "你现在的修为尚且无法用针进行切割。"}
          else
            {:ok, "$N轻弹出手中#{wname}，勾勒出一道绚丽的弧芒，将$n的#{part_name(part)}割了下来。"}
          end

        skill_type == "hammer" ->
          if Map.get(skill, "hammer", 0) < 100 do
            {:error, "你现在的锤法修为尚且无法进行切割。"}
          else
            {:ok, "$N蓦地挥动#{wname}，听得「哐咚」一声闷响，已将$n的#{part_name(part)}砸了下来。"}
          end

        true ->
          {:ok, "$N提起手中#{wname}「嗤」的一声便将$n的#{part_name(part)}割了下来。"}
      end
    else
      if force < 90 do
        {:error_force, part_name(part)}
      else
        {:ok, "$N举起手来，一下子就把$n的#{part_name(part)}切了下来。"}
      end
    end
  end
end

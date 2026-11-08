defmodule Kantele.Character.Precepts do
  @moduledoc """
  戒律系统（对应 LPC 少林 `guilty` 戒律计数，updated.c / shaolin 各 trap·square 写入）。

  LPC 中 `guilty` 是玩家级属性（`me->query("guilty")`）：违戒（杀僧 / 食肉 / 广场斗殴等）
  递增，戒律院（`jlyuan.c`）赦免清零。Elixir 端口此前只有**读取端**
  （`hunyuan-yiqi` / `buddhism` 的 `guilty_of`），**写入端缺失** —— 本模块补齐。

  ## 语义
  - `guilty` 存于 `PlayerMeta.guilty`，落盘 `character_metadata.guilty`（records.ex 镜像
    `personality` 的 save/load 模式）。
  - `violate/2`：破戒 +n。`amount` 为整数直接加；为 atom 时查 `@reason_amounts`
    （未知 reason 兜底 +1），与 LPC 各 trap/square 的 `set("guilty", N)` 对齐。
  - `guilty_of/1`：读取（与技能侧 `guilty_of` 同款，nil / 非整数视作 0）。
  - `clear/1`：戒律院赦免，清零。

  ## 侦测辅助（供命令 / 事件层调用）
  - `meat_item?/1`：食物是否破荤戒（item.meta.is_meat 为真）。
  - `monk_name?/1`：击杀目标名是否少林僧侣（子串启发式 v0；NPC 数据侧可改用
    meta.is_monk 精确标注，但 `enemy_died` 仅拿到 reward.name，故先用子串）。
  """

  alias Kalevala.Character
  alias Kantele.Character.PlayerMeta

  # 破戒权重（对应 LPC 各 trap/square 的 set("guilty", N)）
  @reason_amounts %{
    eat_meat: 1,
    kill_monk: 1,
    square_fight: 1,
    monk_trap: 3
  }

  # 少林僧侣名子串启发式（v0）。NPC 数据若标注 meta.is_monk=true 更精确，但 enemy_died
  # 仅拿到 reward.name，故先用子串；如需精确可在此扩充或改查 NPC 注册表。
  @monk_substrings ["僧", "少林", "罗汉", "达摩", "武僧"]

  @doc """
  破戒递增 `meta.guilty`。
  - `amount_or_reason` 为整数 → 直接 +amount（负值=减，语义由调用方决定）。
  - 为 atom → 查 `@reason_amounts`，未知 reason 视作 +1（faithful 兜底）。
  """
  def violate(%Character{} = character, amount_or_reason \\ 1) do
    delta = normalize_amount(amount_or_reason)
    current = guilty_of(character)
    put_guilty(character, current + delta)
  end

  defp normalize_amount(reason) when is_atom(reason), do: Map.get(@reason_amounts, reason, 1)
  defp normalize_amount(n) when is_integer(n), do: n
  defp normalize_amount(_), do: 1

  @doc "读取戒律违犯计数（nil / 非整数 → 0，与技能侧 `guilty_of` 一致）。"
  def guilty_of(%Character{meta: %PlayerMeta{} = meta}), do: extract(meta)
  def guilty_of(%{meta: meta}) when is_map(meta), do: extract(meta)
  def guilty_of(_character), do: 0

  defp extract(%{guilty: n}) when is_integer(n), do: n
  defp extract(_), do: 0

  @doc "戒律院赦免：清零。"
  def clear(%Character{} = character) do
    put_guilty(character, 0)
  end

  defp put_guilty(%Character{meta: %PlayerMeta{} = meta} = character, value) do
    %{character | meta: %{meta | guilty: value}}
  end

  defp put_guilty(%Character{meta: meta} = character, value) when is_map(meta) do
    %{character | meta: Map.put(meta, :guilty, value)}
  end

  # ---- 侦测辅助 ----------------------------------------------------------

  @doc "食物是否破荤戒（item.meta.is_meat 为真）。"
  def meat_item?(%{meta: meta}) when is_map(meta), do: Map.get(meta, :is_meat) == true
  def meat_item?(_item), do: false

  @doc "名字是否疑似少林僧侣（子串启发式 v0）。"
  def monk_name?(nil), do: false
  def monk_name?(name) when is_binary(name), do: Enum.any?(@monk_substrings, &String.contains?(name, &1))
  def monk_name?(_), do: false
end

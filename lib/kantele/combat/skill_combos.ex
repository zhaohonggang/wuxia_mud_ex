defmodule Kantele.Combat.SkillCombos do
  @moduledoc """
  拳术组合白名单（LPC `valid_combine` 的移植）。

  数据源：LPC `kungfu/skill/*.c` 中每个技能文件的
  `int valid_combine(string combo)` 返回值，以及已落地的 Elixir 技能模块
  中定义的 `valid_combine/1` 回调。

  LPC 语义：`SKILL_D(skill)->valid_combine(other)` 判定两种特殊拳术能否
  组合预备（`cmds/skill/prepare.c`）。键为技能 id（连字符，与
  `Kantele.Combat.Skills.@static` 一致），值为允许与之组合的技能 id 列表。

  注：全量扫描 `/c/files/git/mud/kungfu/skill/*.c` 并未发现任何
  `valid_combine` 定义（LPC 源本身不包含此函数）。现有条目均来自
  已落地的 Elixir 技能模块（当前仅 `taiji-quan` 定义 `valid_combine/1`）。

  注：LPC 语义按方向查询，与 `SKILL_D(skill)->valid_combine(other)` 一致，
  不自动补全反向关系。
  """

  @combos %{
    "taiji-quan" => ["wudang-zhang", "paiyun-shou"]
  }

  @doc "返回全部组合表（skill_id -> [允许组合的 skill_id]）。"
  def all, do: @combos

  @doc "某技能声明的可组合技能列表；未定义 valid_combine 的技能返回 `[]`。"
  def for(skill_id) when is_binary(skill_id), do: Map.get(@combos, skill_id, [])

  @doc "LPC `SKILL_D(skill)->valid_combine(other)` 等价判定（有方向）。"
  def valid_combine?(skill, other) when is_binary(skill) and is_binary(other),
    do: other in Map.get(@combos, skill, [])

  @doc "技能数（声明 valid_combine 的技能数量）。"
  def size, do: map_size(@combos)

  @doc "组合关系总数（所有允许方向的条目之和）。"
  def pair_count, do: Enum.reduce(@combos, 0, fn {_k, v}, acc -> acc + length(v) end)
end

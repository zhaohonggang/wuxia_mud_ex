defmodule Kantele.Combat.Skills.ZuoyouHubo do
  @moduledoc """
  左右互博（对照 `kungfu/skill/zuoyou-hubo.c`）

  知识类（`type() == "knowledge"`）：无招式表、不可 enable 到任何用法。

  已按 LPC 迁移（2026-10-31）：

    - `valid_learn/2`：无性且等级 >= 50 拒绝；已通算术（`count`）或有
      `special_skill/qinzong` 拒绝；悟性 > 15 且无 `special_skill/tiandao` 拒绝；
      `force < lvl * 3 / 4` 拒绝。
    - `practice_cost/0` 返回 `nil`（LPC `practice_skill` 直接 `notify_fail`，
      只能靠学）。

  未建模：LPC `skill_improved` 的「第 N 层境界」提示（该回调只拿到 `Stats`，
  无消息通道；且不改任何受建模的基础属性），保留默认保真。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.SpecialSkills
  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "zuoyou-hubo"

  # 源无 valid_enable —— LPC 调用未定义函数即失败，故任何用法均不可 enable。
  @impl true
  def valid_enable(_usage), do: false

  @doc "只能学(learn)不能练（LPC practice_skill 返回 notify_fail）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    # LPC: me->query("int") > 15（裸属性，非 query_int 派生值）
    int = Stats.int(stats)

    cond do
      gender_of(character) == "无性" and lvl >= 50 ->
        {:error, "你默默凝神，试图分心二用，可是却觉得阴阳失调，心浮气躁。\n"}

      Stats.skill(stats, "count") > 0 or owns_special?(character, "qinzong") ->
        {:error, "你受到阴阳八卦影响甚深，难以尝试更高深的分心之术。\n"}

      int > 15 and not owns_special?(character, "tiandao") ->
        {:error, "你觉得心烦意乱，难以尝试更高深的分心之术。\n"}

      # LPC: (int)me->query_skill("force") < lvl * 3 / 4（C 整数除法）
      Stats.skill(stats, "force") < div(lvl * 3, 4) ->
        {:error, "你的内功火候不够，难以轻松自如的分运两股内力。\n"}

      true ->
        :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  # 特技存放形状：完整 Character 在 `attributes`，learn 事件的切片不带该字段
  defp owns_special?(%{attributes: attributes}, skill_id),
    do: SpecialSkills.owned?(attributes, skill_id)

  defp owns_special?(_character, _skill_id), do: false

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

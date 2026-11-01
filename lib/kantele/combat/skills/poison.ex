defmodule Kantele.Combat.Skills.Poison do
  @moduledoc """
  武学实装「poison」（源 poison.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  **已迁移**：`valid_learn/2` 人格门（LPC `me->query("character") == "光明磊落"` →
  `notify_fail("你心中暗想：我行事光明磊落，学什么毒技！\n")`），
  `practice_cost/0`（LPC 无 practice_skill，沿用基类默认 qi/neili）。

  无动态招式，无 perform/exert（毒技为被动/辅助类技能）。
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "poison"

  # LPC 源未定义 valid_enable（未定义函数调用即失败），保真写法返回 false。
  @impl true
  def valid_enable(_usage), do: false

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  # LPC valid_learn(object me)：
  #   if (me->query("character") == "光明磊落")
  #     return notify_fail("你心中暗想：我行事光明磊落，学什么毒技！\n");
  #   return 1;
  @impl true
  def valid_learn(_stats, character) do
    cond do
      character.meta.character == "光明磊落" ->
        {:error, "你心中暗想：我行事光明磊落，学什么毒技！\n"}

      true ->
        :ok
    end
  end

  @doc "练习消耗：LPC 无 practice_skill 覆盖，沿用基类默认 %{qi: 50, neili: 30}"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 30}

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

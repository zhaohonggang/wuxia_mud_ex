defmodule Kantele.Combat.Skills.LuoyunDao do
  @moduledoc """
  洛云刀法（对照 `kungfu/skill/luoyun-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/luoyun_dao/`。

  学习门槛 `valid_learn/2`（max_neili>=400 / force>=100 / blade>=80 / blade>=luoyun-dao）与
  练招消耗 `practice_cost`（LPC 扣 qi 45 / neili 35，须持刀）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持刀（weapon skill_type=="blade"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表沿用基类占位 TODO；LPC 末门文案 verbatim「孤星剑法」「基本剑法」保真不修。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "luoyun-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 45 / neili 35（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 45, neili: 35}

  # LPC `valid_learn(object me)`（源 luoyun-dao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "blade" ->
        {:error, "你必须先找一把剑才能练落云刀法。\n"}

      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你目前的内力修为不够，没有办法练落云刀法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功修为不够，没有办法练落云刀法。\n"}

      Stats.skill(stats, "blade") < 80 ->
        {:error, "你的基本剑法火候太浅，没有办法练落云刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的孤星剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"tian" => Kantele.Combat.Skills.Performs.LuoyunDao.Tian}
  end
end

defmodule Kantele.Combat.Skills.FurongJian do
  @moduledoc """
  芙蓉剑法（对照 `kungfu/skill/furong-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/furong_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求持剑、max_neili>=300、未合 wushen-jian，
    本版以 force>=100 代理；
  - LPC `main_skill("wushen-jian")` 合成用法未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "furong-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 furong-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "wushen-jian") > 0 ->
        {:error, "你已演练合成了衡山五神剑，不必再单独学习。\n"}

      (not (Skill.wielding?(character))) or (Skill.wielded_skill_type(character) != "sword") ->
        {:error, "你必须先找一把剑才能练剑法。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够，没有办法练芙蓉剑法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 60 ->
        {:error, "你的基本剑法火候不够，无法学习芙蓉剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的芙蓉剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"luan" => Kantele.Combat.Skills.Performs.FurongJian.Luan}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end

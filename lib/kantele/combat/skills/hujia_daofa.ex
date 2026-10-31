defmodule Kantele.Combat.Skills.HujiaDaofa do
  @moduledoc """
  胡家刀法（对照 `kungfu/skill/hujia-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hujia_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1400 且未习得 daojian-guizhen，
    本版以 force>=80 代理（互斥项未建模）；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "hujia-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 hujia-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "daojian-guizhen") > 0 ->
        {:error, "你已经将苗家剑法和胡家刀法二者合一了。\n"}

      not is_nil(max_neili) and max_neili < 1400 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 120 ->
        {:error, "你的基本刀法火候不够，无法学习胡家刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平有限，无法领会更高深的胡家刀法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "cang" => Kantele.Combat.Skills.Performs.HujiaDaofa.Cang,
      "xian" => Kantele.Combat.Skills.Performs.HujiaDaofa.Xian,
      "zhui" => Kantele.Combat.Skills.Performs.HujiaDaofa.Zhui
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end

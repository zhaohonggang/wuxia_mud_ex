defmodule Kantele.Combat.Skills.RanmuDaofa do
  @moduledoc """
  燃木刀法（对照 `kungfu/skill/ranmu-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/ranmu_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=2000 与「必须持刀」门槛本版省略
    （max_neili 以 force>=250 代理；持刀判断引擎 `valid_learn/1`
    只拿 stats 无从查询装备）；
  - LPC 招式表与 `practice_skill` 未建模（`query_action` 返回空、
    `practice_cost` 为 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "ranmu-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 ranmu-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "blade" ->
        {:error, "你必须先找一把刀才能练燃木刀法。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力不足，没有办法练燃木刀法，多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 250 ->
        {:error, "你的内功火候太浅，没有办法练燃木刀法。\n"}

      Stats.skill(stats, "blade") < 100 ->
        {:error, "你的基本刀法火候太浅，没有办法练燃木刀法。\n"}

      Stats.skill(stats, "blade") < lvl ->
        {:error, "你的基本刀法水平还不够，无法领会更高深的燃木刀法。\n"}

      (Stats.int(stats) < 32) or (Stats.con(stats) < 30) ->
        {:error, "你先天太差，难以领会燃木刀法的要诣。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "huo" => Kantele.Combat.Skills.Performs.RanmuDaofa.Huo,
      "zhenyan" => Kantele.Combat.Skills.Performs.RanmuDaofa.Zhenyan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end

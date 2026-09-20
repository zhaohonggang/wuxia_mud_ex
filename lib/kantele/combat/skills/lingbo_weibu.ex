defmodule Kantele.Combat.Skills.LingboWeibu do
  @moduledoc """
  凌波微步（对照 `kungfu/skill/lingbo-weibu.c`）

  轻功载体：`valid_enable("dodge")`。

  绝招实现见 `lib/kantele/combat/skills/performs/lingbo_weibu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=3000+lvl*15 门槛本版未代理（引擎
    `valid_learn/1` 只拿 stats，无 vitals），仅以 dex>=30 校验；
  - LPC `valid_damage`/`query_effect_dodge` 被动（身法幻影抵消伤害）与
    `dodge_msg` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "lingbo-weibu"

  @impl true
  def valid_enable(usage), do: usage == "dodge"

  @impl true
  def valid_learn(stats) do
    if stats.dex < 30 do
      {:error, "你先天身法太差，无法学习凌波微步。\n"}
    else
      :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"ling" => Kantele.Combat.Skills.Performs.LingboWeibu.Ling}
  end
end
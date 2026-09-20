defmodule Kantele.Combat.Skills.KuangfengJian do
  @moduledoc """
  狂风快剑（对照 `kungfu/skill/kuangfeng-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/kuangfeng_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=200 门槛本版以 dodge>=90 代理（引擎
    `valid_learn/1` 只拿 stats，无 vitals）；
  - LPC 招式表与 `practice_skill`（须持剑 qi65/neili40）未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "kuangfeng-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "dodge") < 90 ->
        {:error, "你的基本轻功火候太浅，无法修习狂风快剑。\n"}

      stats.dex < 28 ->
        {:error, "你的身法还不够灵活，无法修习狂风快剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的狂风快剑。\n"}

      true ->
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
    %{"sao" => Kantele.Combat.Skills.Performs.KuangfengJian.Sao}
  end
end
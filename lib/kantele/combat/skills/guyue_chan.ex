defmodule Kantele.Combat.Skills.GuyueChan do
  @moduledoc """
  孤月铲法（对照 `kungfu/skill/guyue-chan.c`）

  铲/杖载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/guyue_chan/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求持杖、max_neili>=400，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "guyue-chan"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 guyue-chan.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "staff" ->
        {:error, "你使用的武器不对。\n"}

      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你的内力修为不足，无法学习孤月铲法。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅，无法学习孤月铲法。\n"}

      Stats.skill(stats, "staff") < 20 ->
        {:error, "你的基本杖法太浅，无法学习孤月铲法。\n"}

      Stats.skill(stats, "staff") < Stats.skill(stats, "poshui-zhang") ->
        {:error, "你的基本杖法水平有限，无法领会更高深的孤月铲法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"jing" => Kantele.Combat.Skills.Performs.GuyueChan.Jing}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end

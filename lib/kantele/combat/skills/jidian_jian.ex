defmodule Kantele.Combat.Skills.JidianJian do
  @moduledoc """
  疾电剑法（对照 `kungfu/skill/jidian-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jidian_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=200、dodge>=60、dex>=25、
    sword>=jidian-jian，本版以 force>=50 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jidian-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 jidian-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力不够，无法修习疾电剑法。\n"}

      Stats.skill(stats, "dodge") < 60 ->
        {:error, "你的轻功火候太浅，无法修习疾电剑法。\n"}

      Stats.query_dex(stats) < 25 ->
        {:error, "你的身法还不够灵活，无法修习疾电剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的疾电剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"dian" => Kantele.Combat.Skills.Performs.JidianJian.Dian}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end

defmodule Kantele.Combat.Skills.DuanjiaJian do
  @moduledoc """
  段家剑法（对照 `kungfu/skill/duanjia-jian.c`）

  剑/杖法载体：`valid_enable("sword")`、`valid_enable("staff")`；
  `valid_force` 接受 基本剑法/基本杖法/段家剑法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/duanjia_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=300 / 基本剑法>=30 门槛本版以 force 等级代理；
  - LPC `practice_skill` 训练（qi 45 / neili 36）未建模（`practice_cost` 返回 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanjia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "staff"]

  @impl true
  def valid_force(force), do: force in ["basic-sword", "basic-staff", "duanjia-jian"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 duanjia-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "sword") < 30 ->
        {:error, "你的基本剑法火候太浅。\n"}

      (Stats.skill(stats, "sword") < lvl) and (Stats.skill(stats, "staff") < lvl) ->
        {:error, "你的基本剑法或杖法火候不够，无法领会更高深的段家剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "lian" => Kantele.Combat.Skills.Performs.DuanjiaJian.Lian,
      "jing" => Kantele.Combat.Skills.Performs.DuanjiaJian.Jing
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

end

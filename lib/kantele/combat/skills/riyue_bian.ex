defmodule Kantele.Combat.Skills.RiyueBian do
  @moduledoc """
  日月鞭法（对照 `kungfu/skill/riyue-bian.c`）

  鞭法载体：`valid_enable("whip")`、`valid_enable("parry")`；
  `valid_force` 接受 日月心法/日月鞭法 共存。

  绝招：`perform_list/0` 提供 缠绕「chan」、合字诀「he」、伤字诀「shang」。

  学习门槛 `valid_learn/2`（int>=30 / con>=32 / max_neili>=1000 / force>=150 / whip>=100 / whip>=self）与
  练招消耗 `practice_cost`（qi 75 / neili 85）已按 LPC 迁移（2026-10-30）。须持鞭检查由 practice 流程把关。
  - 三个绝招的 `living(target)` 检查、chan 的目标 busy 先行拒绝 等目标侧门内断言
    视目标进程不可读而省略；he 的逐次 `do_attack` 折算为一次合计伤害（见模块文档）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @allowed_forces ~w(riyue-xinfa riyue-bian)

  @impl true
  def id(), do: "riyue-bian"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_force(force), do: force in @allowed_forces

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 85}

  # LPC `valid_learn(object me)`（源 riyue-bian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练鞭法。\n"}

      Stats.int(stats) < 30 ->
        {:error, "你觉得日月鞭法过于艰深，难以理解。\n"}

      Stats.con(stats) < 32 ->
        {:error, "你的先天根骨孱弱，无法运转日月鞭法。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不足，没有办法练日月鞭法，多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅，没有办法练日月鞭法。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练日月鞭法。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的日月鞭法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.RiyueBian.Chan,
      "he" => Kantele.Combat.Skills.Performs.RiyueBian.He,
      "shang" => Kantele.Combat.Skills.Performs.RiyueBian.Shang
    }
  end
end

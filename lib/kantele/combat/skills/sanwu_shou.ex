defmodule Kantele.Combat.Skills.SanwuShou do
  @moduledoc """
  散手（对照 `kungfu/skill/sanwu-shou.c`）

  鞭/手法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sanwu_shou/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：max_neili>=800 / force>=120 / whip>=100 / whip>=sanwu-shou；
  - LPC 首门「性格须为『心狠手辣』或『国士无双』」为 alignment 门，本仓未建模
    （无 alignment 字段/设定入口），**未迁移**；
  - LPC 的「须持鞭（`skill_type=="whip"`）」检查由 practice 流程把关，未写入 `valid_learn`；
  - LPC `practice_skill` 已迁移：qi 55 / neili 60；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanwu-shou"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力不足，没有办法练三无三不手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，没有办法练三无三不手。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练三无三不手。\n"}

      Stats.skill(stats, "whip") < Stats.skill(stats, id()) ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的没有办法练三无三不手。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 60（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 60}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "kong" => Kantele.Combat.Skills.Performs.SanwuShou.Kong,
      "wei" => Kantele.Combat.Skills.Performs.SanwuShou.Wei,
      "zhi" => Kantele.Combat.Skills.Performs.SanwuShou.Zhi
    }
  end
end

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

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanwu-shou"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 60（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 60}

  # LPC `valid_learn(object me)`（源 sanwu-shou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      (personality != "心狠手辣") and (personality != "国士无双") ->
        {:error, "练三无三不手必须要心狠手辣，我看你这点做得还不够。\n"}

      (not (Skill.wielding?(character))) or (Skill.wielded_skill_type(character) != "whip") ->
        {:error, "你必须先找一条鞭子才能练三无三不手。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力不足，没有办法练三无三不手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候太浅，没有办法练三无三不手。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练三无三不手。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平有限，无法领会更高深的没有办法练三无三不手。\n"}

      true ->
        :ok
    end
  end

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

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :personality)
  defp personality_of(_character), do: nil

end

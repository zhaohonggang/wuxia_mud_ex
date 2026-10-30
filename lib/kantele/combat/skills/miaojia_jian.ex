defmodule Kantele.Combat.Skills.MiaojiaJian do
  @moduledoc """
  苗家剑法（对照 `kungfu/skill/miaojia-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/miaojia_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：已学 `daojian-guizhen` 则拒（刀剑合一互斥）/ max_neili>=1300 /
    force>=150 / sword>=120 / sword>=miaojia-jian；
  - LPC `practice_skill` 已迁移：qi 53 / neili 84，且同样带「已学 `daojian-guizhen` 则拒」与
    「须持剑（`skill_type=="sword"`）」两道门——前者已并入 `valid_learn`（practice 流程会复用），
    后者由 practice 流程把关；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "miaojia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "daojian-guizhen") > 0 ->
        {:error, "你已经将苗家剑法和胡家刀法二者合一了。\n"}

      not is_nil(max_neili) and max_neili < 1300 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 120 ->
        {:error, "你的基本剑法火候不够，无法学习苗家剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的苗家剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 53 / neili 84（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 53, neili: 84}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "gan" => Kantele.Combat.Skills.Performs.MiaojiaJian.Gan,
      "qian" => Kantele.Combat.Skills.Performs.MiaojiaJian.Qian,
      "zhai" => Kantele.Combat.Skills.Performs.MiaojiaJian.Zhai,
      "zhu" => Kantele.Combat.Skills.Performs.MiaojiaJian.Zhu
    }
  end
end

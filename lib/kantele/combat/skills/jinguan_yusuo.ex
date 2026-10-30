defmodule Kantele.Combat.Skills.JinguanYusuo do
  @moduledoc """
  金刚玉锁（对照 `kungfu/skill/jinguan-yusuo.c`）

  内功/锁法载体：`valid_enable("force")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jinguan_yusuo/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：taoism>=150 / force>=150 / parry>=150 / max_neili>=1800 /
    force>=jinguan-yusuo / parry>=jinguan-yusuo；
  - LPC `practice_skill` 已迁移：qi 80 / neili 90。其**额外一道**「自身等级<200 则拒
    （『你对金关玉锁了解甚浅，不足以自行锻炼。』）」为 practice 专属门，当前引擎无
    `valid_practice` 回调、`practice_cost/0` 也无法表达条件，故**未建模**；
  - LPC `valid_enable` 仅 `"parry"`，本仓另注册了 `"force"`（历史遗留，改动会影响已激发内功的
    角色，暂不修改，仅记差异）；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jinguan-yusuo"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    self_lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "taoism") < 150 ->
        {:error, "你对道学理解不够深入，无法学习金关玉锁。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的基本内功火候不够，无法学习金关玉锁。\n"}

      Stats.skill(stats, "parry") < 150 ->
        {:error, "你的基本招架火候不够，无法学习金关玉锁。\n"}

      not is_nil(max_neili) and max_neili < 1800 ->
        {:error, "你目前的内力修为不足，无法学习金关玉锁。\n"}

      Stats.skill(stats, "force") < self_lvl ->
        {:error, "你的基本内功水平有限，无法领会更高深的金关玉锁。\n"}

      Stats.skill(stats, "parry") < self_lvl ->
        {:error, "你的基本招架水平有限，无法领会更高深的金关玉锁。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 80 / neili 90（自身<200 的 practice 专属门未建模）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 90}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"suo" => Kantele.Combat.Skills.Performs.JinguanYusuo.Suo}
  end
end

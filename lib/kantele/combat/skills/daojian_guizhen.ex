defmodule Kantele.Combat.Skills.DaojianGuizhen do
  @moduledoc """
  刀剑归真（对照 `kungfu/skill/daojian-guizhen.c`）

  刀剑双修载体：`valid_enable("blade")` / `valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/daojian_guizhen/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：int>=35 / dex>=25 / martial-cognize>=250 / max_neili>=4500 /
    sword>=250 且 blade>=250 / 「刀剑均低于本技能」/「其一低于本技能」两道根基门；
  - LPC 首门「须持剑或持刀」未写入 `valid_learn`（`character` 快照不含持械信息），
    且 LPC `practice_skill` 亦未复查武器，故该门当前**无执行点**（已知差异）；
  - LPC 第二门「性格须为『光明磊落』或『国士无双』」为 alignment 门，本仓未建模，**未迁移**；
  - LPC 末门允许 `ultrap(me)` 且刀剑均 >=320 时只需其一达标；本仓无 `ultrap`（大宗师）判定，
    故按非大宗师处理（其一不达标即拒），对现有全部角色均等价；
  - LPC `practice_skill` 已迁移：qi 85 / neili 85；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "daojian-guizhen"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "sword", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    self_lvl = Stats.skill(stats, id())
    sword = Stats.skill(stats, "sword")
    blade = Stats.skill(stats, "blade")

    cond do
      Stats.int(stats) < 35 ->
        {:error, "你研究了半天，却只感剑法和刀法毫无牵连，看来是自己天资不足。\n"}

      Stats.dex(stats) < 25 ->
        {:error, "你研究了半天，只觉依自己的身法灵动性，根本无法修习这门武功。\n"}

      Stats.skill(stats, "martial-cognize") < 250 ->
        {:error, "你觉得苗家剑法和胡家刀法都极其深奥，依照自己武学修养难以理解。\n"}

      not is_nil(max_neili) and max_neili < 4500 ->
        {:error, "你的内力太弱，无法将苗家剑法和胡家刀法二者合一学习。\n"}

      sword < 250 or blade < 250 ->
        {:error, "你的刀剑根基火候不足，难以修炼刀剑归真。\n"}

      sword < self_lvl and blade < self_lvl ->
        {:error, "你的刀剑根基火候不足，无法领会更高深的刀剑归真。\n"}

      sword < self_lvl or blade < self_lvl ->
        {:error, "你的刀法或剑法火候不足，无法领会更高深的刀剑归真。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 85 / neili 85"
  @impl true
  def practice_cost(), do: %{qi: 85, neili: 85}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "daojian" => Kantele.Combat.Skills.Performs.DaojianGuizhen.Daojian,
      "xue" => Kantele.Combat.Skills.Performs.DaojianGuizhen.Xue
    }
  end
end

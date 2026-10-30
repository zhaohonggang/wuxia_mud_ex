defmodule Kantele.Combat.Skills.CibeiDao do
  @moduledoc """
  慈悲刀法（对照 `kungfu/skill/cibei-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  招式表为纯数据（`@actions`，取 LPC `action` 表的 8 式静态招式），选招用
  `Kantele.Combat.Skill.pick_action/3`（LPC `NewRandom` 加权，`level > lvl`
  严格过滤）。

  绝招实现见 `lib/kantele/combat/skills/performs/cibei_dao/`。

  学习门槛 `valid_learn/2`（含 max_neili>=100，原 /1 版因无 vitals 漏判）与练招消耗
  `practice_cost`（LPC 扣 qi 55 / neili 58，须持刀）已按 LPC 迁移（2026-10-30）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w斜指，一招「停车问路」，反身一顿，一刀向$n的$l撩去",
      "force" => 40,
      "attack" => 10,
      "dodge" => -10,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0,
      "skill_name" => "停车问路",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一招「童子挂画」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 90,
      "attack" => 20,
      "dodge" => -10,
      "parry" => 8,
      "damage" => 5,
      "lvl" => 10,
      "skill_name" => "童子挂画",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「推窗望月」，刀锋一卷，拦腰斩向$n",
      "force" => 140,
      "attack" => 25,
      "dodge" => -5,
      "parry" => 12,
      "damage" => 15,
      "lvl" => 30,
      "skill_name" => "推窗望月",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一招「开门见山」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 190,
      "attack" => 30,
      "dodge" => 5,
      "parry" => 15,
      "damage" => 25,
      "lvl" => 50,
      "skill_name" => "开门见山",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w一沉，一招「临溪观鱼」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 240,
      "attack" => 35,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 30,
      "lvl" => 80,
      "skill_name" => "临溪观鱼",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N挥舞$w，使出一招「张弓望的」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 280,
      "attack" => 40,
      "dodge" => 15,
      "parry" => 32,
      "damage" => 35,
      "lvl" => 100,
      "skill_name" => "张弓望的",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一招「风送轻舟」，左脚跃步落地，$w顺势往前，挟风声劈向$n的$l",
      "force" => 290,
      "attack" => 45,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 50,
      "lvl" => 120,
      "skill_name" => "风送轻舟",
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N盘身驻地，一招「川流不息」，挥出一片流光般的刀影，向$n的全身涌去",
      "force" => 320,
      "attack" => 50,
      "dodge" => 20,
      "parry" => 45,
      "damage" => 60,
      "lvl" => 150,
      "skill_name" => "停车问路",
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "cibei-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  # LPC valid_learn 要求 max_neili>=100、force>=30、blade>=cibei-dao
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够。\n"}

      Stats.skill(stats, "blade") < Stats.skill(stats, id()) ->
        {:error, "你的基本刀法水平有限，无法领会更高深的慈悲刀法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 58（须持刀，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 58}

  @doc "按等级加权随机选一招（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  # 慈悲刀法无动态招式表，query_action/3 与 /2 行为一致（忽略 attacker）
  @impl true
  def query_action(_level, rng, _attacker), do: query_action(_level, rng)

  @impl true
  def perform_list() do
    %{"sheshen" => Kantele.Combat.Skills.Performs.CibeiDao.Sheshen}
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "当前等级对应的最高招式名（query_skill_name，LPC `level >= lvl`）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> action["skill_name"]
    end
  end
end

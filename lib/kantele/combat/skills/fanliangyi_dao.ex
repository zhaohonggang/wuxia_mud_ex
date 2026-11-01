defmodule Kantele.Combat.Skills.FanliangyiDao do
  @moduledoc """
  反两仪刀法（对照 `kungfu/skill/fanliangyi-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`；
  LPC 的 `valid_enable("array")` 用法本引擎未建模（TODO(migrate)），
  组阵功能经「双剑和壁」绝招（`fanliangyi-dao/makearray`）走队伍系统实现。

  绝招实现见 `lib/kantele/combat/skills/performs/fanliangyi_dao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=150 门槛本版以 force>=40 代理；
  - LPC 招式表与 `practice_skill`（须持刀 qi50/neili50）未建模；
  - LPC master 中组阵成员还须激发紫霞神功（mapped force == zixia-shengong），
    本版以 队长触发方本地校验 代偿（见 makearray 模块）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w斜指，一招「混沌一破」，反身一顿，一刀向$n的$l撩去",
      "force" => 120,
      "dodge" => -10,
      "lvl" => 0,
      "skill_name" => "混沌一破"
    },
    %{
      "action" => "$N一招「太乙生萌」，左右腿虚点，$w一提一收，平刃挥向$n的颈部",
      "force" => 140,
      "dodge" => -10,
      "damage" => 5,
      "lvl" => 20,
      "skill_name" => "太乙生萌"
    },
    %{
      "action" => "$N展身虚步，提腰跃落，一招「两仪合德」，刀锋化作两股斩向$n",
      "force" => 160,
      "dodge" => -5,
      "damage" => 15,
      "lvl" => 40,
      "skill_name" => "两仪合德"
    },
    %{
      "action" => "$N一招「日月晦明」，$w大开大阖，自上而下划出一个大弧，笔直劈向$n",
      "force" => 180,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 60,
      "skill_name" => "日月晦明"
    },
    %{
      "action" => "$N手中$w一沉，一招「无色无相」，双手持刃拦腰反切，砍向$n的胸口",
      "force" => 200,
      "dodge" => 10,
      "damage" => 28,
      "lvl" => 80,
      "skill_name" => "无色无相"
    },
    %{
      "action" => "$N挥舞$w，使出一招「万劫不复」，上劈下撩，左挡右开，齐齐罩向$n",
      "force" => 250,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 100,
      "skill_name" => "万劫不复"
    }
  ]

  @impl true
  def id(), do: "fanliangyi-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fanliangyi-dao.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 150 ->
        {:error, "你的内力修为不够，无法修炼。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候太浅。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "makearray" => Kantele.Combat.Skills.Performs.FanliangyiDao.Makearray,
      "san" => Kantele.Combat.Skills.Performs.FanliangyiDao.San
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

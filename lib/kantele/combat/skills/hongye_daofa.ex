defmodule Kantele.Combat.Skills.HongyeDaofa do
  @moduledoc """
  红叶刀法（对照 `kungfu/skill/hongye-daofa.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/hongye_daofa/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求 max_neili>=1000、hunyuan-yiqi>=80、int>=24，
    本版以 force>=80 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N手中$w轻挥，一招「冬去春来」，身形一转，一刀向$n的$l撩去",
      "force" => 100,
      "attack" => 10,
      "dodge" => -10,
      "parry" => -1,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "冬去春来"
    },
    %{
      "action" => "$N一招「月上西楼」，左脚虚点，$w一收一推，平刃挥向$n的脸部",
      "force" => 130,
      "attack" => 40,
      "dodge" => -10,
      "parry" => 5,
      "damage" => 58,
      "lvl" => 20,
      "skill_name" => "月上西楼"
    },
    %{
      "action" => "$N虚步侧身，一招「推窗望月」，刀锋一卷，拦腰斩向$n",
      "force" => 160,
      "attack" => 40,
      "dodge" => -5,
      "parry" => 25,
      "damage" => 80,
      "lvl" => 40,
      "skill_name" => "推窗望月"
    },
    %{
      "action" => "$N一招「梦断巫山」，$w自上而下划出一个大弧，笔直劈向$n",
      "force" => 190,
      "attack" => 55,
      "dodge" => 5,
      "parry" => 35,
      "damage" => 105,
      "lvl" => 60,
      "skill_name" => "梦断巫山"
    },
    %{
      "action" => "$N侧步拧身，一招「似是而非」，拦腰反切，$w砍向$n的胸口",
      "force" => 220,
      "attack" => 60,
      "dodge" => 10,
      "parry" => 40,
      "damage" => 95,
      "lvl" => 80,
      "skill_name" => "似是而非"
    },
    %{
      "action" => "$N挥舞$w，使出一招「红叶纷纷」，幻起片片刀影，齐齐罩向$n",
      "force" => 240,
      "attack" => 70,
      "dodge" => 15,
      "parry" => 55,
      "damage" => 140,
      "lvl" => 100,
      "skill_name" => "月挂中天"
    },
    %{
      "action" => "$N一招「日月交辉」，只见漫天刀光闪烁，重重刀影向$n的全身涌去",
      "force" => 320,
      "attack" => 70,
      "dodge" => 20,
      "parry" => 60,
      "damage" => 160,
      "lvl" => 120,
      "skill_name" => "日月交辉"
    }
  ]

  @impl true
  def id(), do: "hongye-daofa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 hongye-daofa.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "hunyuan-yiqi") < 80 ->
        {:error, "你的混元一气内功火候太浅。\n"}

      Stats.skill(stats, "blade") < 80 ->
        {:error, "你的基本刀法火候太浅。\n"}

      Stats.int(stats) < 24 ->
        {:error, "你的先天悟性不足。\n"}

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
      "kuang" => Kantele.Combat.Skills.Performs.HongyeDaofa.Kuang,
      "leiting" => Kantele.Combat.Skills.Performs.HongyeDaofa.Leiting
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

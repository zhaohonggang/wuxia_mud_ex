defmodule Kantele.Combat.Skills.LuohanQuan do
  @moduledoc """
  罗汉拳（对照 kungfu/skill/luohan-quan.c）

  拳法载体：`valid_enable("cuff")` / `valid_enable("parry")`。
  招式表为纯数据（`@actions`，取 LPC `action` 表的 8 式静态招式），选招用 `Kantele.Combat.Skill.pick_action/3`（LPC `NewRandom` 加权）。

  绝招实现见 `lib/kantele/combat/skills/performs/luohan_quan/`。

  **未迁移**：`valid_learn` 门槛（LPC 要求 dex >= 30 且 max_neili >= 3000 + lvl * 15）—— 见 TODO(migrate)。
  """

  use Kantele.Combat.Skill
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N连续上步，一式「黄莺落架」，左右手分靠，变拳为掌，击向$n的$l",
      "force" => 80,
      "attack" => 12,
      "parry" => 14,
      "dodge" => 5,
      "lvl" => 0,
      "skill_name" => "黄莺落架",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左脚虚踏，全身右转，一招「丹凤朝阳」，右掌猛地插向$n的$l",
      "force" => 100,
      "attack" => 15,
      "parry" => 16,
      "dodge" => 10,
      "lvl" => 8,
      "skill_name" => "丹凤朝阳",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手大开大阖，宽打高举，使一招「洛钟东应」，双拳向$n的$l打去",
      "force" => 120,
      "attack" => 18,
      "parry" => 19,
      "dodge" => 5,
      "lvl" => 15,
      "skill_name" => "洛钟东应",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌圈花扬起，屈肘当胸，虎口朝上，一招「偏花七星」打向$n的$l",
      "force" => 140,
      "attack" => 20,
      "parry" => 20,
      "dodge" => 10,
      "lvl" => 24,
      "skill_name" => "偏花七星",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一招「苦海回头」，上身前探，双手划了个半圈，击向$n的$l",
      "force" => 150,
      "attack" => 22,
      "parry" => 23,
      "dodge" => 15,
      "lvl" => 33,
      "skill_name" => "苦海回头",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双掌划弧，一记「挟山超海」，掌出如电，一下子切到$n的手上",
      "force" => 170,
      "attack" => 23,
      "parry" => 24,
      "dodge" => 10,
      "lvl" => 42,
      "skill_name" => "挟山超海",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N施出「慑服外道」，双拳拳出如风，同时打向$n头，胸，腹三处要害",
      "force" => 200,
      "attack" => 25,
      "parry" => 24,
      "dodge" => 5,
      "lvl" => 50,
      "skill_name" => "慑服外道",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左脚内扣，右腿曲坐，一式「三入地狱」，双手齐齐按向$n的胸口",
      "force" => 210,
      "attack" => 28,
      "parry" => 25,
      "dodge" => 10,
      "lvl" => 58,
      "skill_name" => "三入地狱",
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "luohan-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  # LPC valid_learn 要求 dex >= 30 且 max_neili >= 3000 + lvl * 15，本引擎暂未建模
  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @doc "按等级加权随机选一式（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  # 罗汉拳无动态招式表，query_action/3 与 /2 行为一致（忽略 attacker）
  @impl true
  def query_action(_level, rng, _attacker), do: query_action(_level, rng)

  @impl true
  def perform_list() do
    %{"xiangmo" => Kantele.Combat.Skills.Performs.LuohanQuan.Xiangmo}
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "当前等级对应的最高招式名（query_skill_name）"
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

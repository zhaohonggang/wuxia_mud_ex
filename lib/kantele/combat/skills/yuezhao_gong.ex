defmodule Kantele.Combat.Skills.YuezhaoGong do
  @moduledoc """
  武学实装「yuezhao-gong」（源 yuezhao-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yuezhao_gong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N使一招「越爪手」，双手如钩如戢，插向$n的$l",
      "force" => 100,
      "attack" => 28,
      "parry" => 0,
      "dodge" => 17,
      "damage" => 13,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "越爪手"
    },
    %{
      "action" => "$N身形一跃，费神扑上，使出一招「追云手」，右手直直抓向$n的$l",
      "force" => 130,
      "attack" => 35,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 10,
      "damage_type" => "抓伤",
      "skill_name" => "追云手"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，一招「蟠龙手」打向$n的$l",
      "force" => 160,
      "attack" => 39,
      "parry" => 10,
      "dodge" => 32,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "抓伤",
      "skill_name" => "蟠龙手"
    },
    %{
      "action" => "$N使出一招「追风逐电」，悄无声息的游走至$n身前，猛的一爪奋力抓向$n的$l",
      "force" => 172,
      "attack" => 42,
      "parry" => 19,
      "dodge" => 38,
      "damage" => 29,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "追风逐电"
    },
    %{
      "action" => "$N双手平提胸前，左手护住面门，一招「单刀赴会」右手推向$n的$l",
      "force" => 187,
      "attack" => 45,
      "parry" => 21,
      "dodge" => 41,
      "damage" => 33,
      "lvl" => 60,
      "damage_type" => "抓伤",
      "skill_name" => "单刀赴会"
    },
    %{
      "action" => "$N使出「双龙开破」，低喝一声，双手化掌为爪，一前一后抓向$n的$l",
      "force" => 203,
      "attack" => 51,
      "parry" => 22,
      "dodge" => 49,
      "damage" => 36,
      "lvl" => 80,
      "damage_type" => "抓伤",
      "skill_name" => "双龙开破"
    },
    %{
      "action" => "$N右腿斜插$n二腿之间，一招「三顾茅庐」，上手取目，下手反勾$n的裆部",
      "force" => 245,
      "attack" => 56,
      "parry" => 27,
      "dodge" => 53,
      "damage" => 41,
      "lvl" => 100,
      "damage_type" => "抓伤",
      "skill_name" => "三顾茅庐"
    },
    %{
      "action" => "$N使出「卧薪尝胆」，双爪如狂风骤雨般对准$n的$l连续抓出",
      "force" => 270,
      "attack" => 61,
      "parry" => 38,
      "dodge" => 58,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "抓伤",
      "skill_name" => "卧薪尝胆"
    }
  ]

  @impl true
  def id(), do: "yuezhao-gong"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 69}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
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
      action -> Map.get(action, "skill_name")
    end
  end


  @impl true
  def perform_list() do
    %{
      "shi" => Kantele.Combat.Skills.Performs.YuezhaoGong.Shi
    }
  end
end

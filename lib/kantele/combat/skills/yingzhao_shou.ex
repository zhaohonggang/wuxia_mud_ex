defmodule Kantele.Combat.Skills.YingzhaoShou do
  @moduledoc """
  武学实装「yingzhao-shou」（源 yingzhao-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yingzhao_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N使一招「苍鹰袭兔」，双手如钩如戢，插向$n的$l",
      "force" => 60,
      "attack" => 0,
      "parry" => 1,
      "dodge" => 17,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N身形一跃，费神扑上，使出一招「雄鹰展翅」，右手直直抓向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 3,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，一招「拔翅横飞」打向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 32,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N使出一招「迎风振翼」，悄无声息的游走至$n身前，猛的一爪奋力抓向$n的$l",
      "force" => 132,
      "attack" => 0,
      "parry" => 19,
      "dodge" => 38,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双手平提胸前，左手护住面门，一招「拨云瞻日」右手推向$n的$l",
      "force" => 137,
      "attack" => 0,
      "parry" => 21,
      "dodge" => 41,
      "damage" => 7,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N使出「搏击长空」，低喝一声，双手化掌为爪，一前一后抓向$n的$l",
      "force" => 143,
      "attack" => 0,
      "parry" => 22,
      "dodge" => 49,
      "damage" => 9,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N使出「鹰扬万里」，双爪如狂风骤雨般对准$n的$l连续抓出",
      "force" => 151,
      "attack" => 0,
      "parry" => 38,
      "dodge" => 58,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "yingzhao-shou"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 50}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

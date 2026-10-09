defmodule Kantele.Combat.Skills.WudangZhang do
  @moduledoc """
  武学实装「wudang-zhang」（源 wudang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wudang_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「苍松迎客」，单掌平推，拍向$n的$l",
      "force" => 10,
      "attack" => 0,
      "parry" => 2,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "苍松迎客"
    },
    %{
      "action" => "$N使一招「峰回路转」，右手划了一个圈子，左手挥出，劈向$n的$l",
      "force" => 15,
      "attack" => 0,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 0,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "峰回路转"
    },
    %{
      "action" => "$N右手由钩变掌，使一招「奇峰突现」，横扫$n的$l",
      "force" => 15,
      "attack" => 0,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "奇峰突现"
    },
    %{
      "action" => "$N双手划弧，右手向上，左手向下，使一招「白鹤亮翅」，分击$n的面门和$l",
      "force" => 25,
      "attack" => 0,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "白鹤亮翅"
    },
    %{
      "action" => "$N左手划了一个大圈，使一招「五行柳变」，击向$n的$l",
      "force" => 25,
      "attack" => 0,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "五行柳变"
    },
    %{
      "action" => "$N双手合掌，使一招「灵猴采桃」，双掌分别向$n的$l打去",
      "force" => 30,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 28,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "灵猴采桃"
    },
    %{
      "action" => "$N左手横于胸前，右掌直击$n的$l，正是一招「仙人指路」",
      "force" => 35,
      "attack" => 0,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 0,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "仙人指路"
    },
    %{
      "action" => "$N左脚前踏半步，双掌猛然齐出,一招「釜底抽薪」，向$n的$l拍去",
      "force" => 35,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 26,
      "damage" => 0,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "釜底抽薪"
    },
    %{
      "action" => "$N双手翻飞，化作无数掌影，一招「漫天花舞」，直逼$n",
      "force" => 20,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 28,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "漫天花舞"
    }
  ]

  @impl true
  def id(), do: "wudang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 50}

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

end

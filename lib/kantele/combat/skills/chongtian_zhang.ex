defmodule Kantele.Combat.Skills.ChongtianZhang do
  @moduledoc """
  武学实装「chongtian-zhang」（源 chongtian-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/chongtian_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双掌骤起，一招「下步摘星势」，一掌击向$n面门，另一掌却按向$n小腹",
      "force" => 185,
      "attack" => 9,
      "parry" => 12,
      "dodge" => 11,
      "damage" => 12,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "下步摘星势"
    },
    %{
      "action" => "$N双掌互错，变幻莫测，一招「洗剑怀中抱月」，瞬息之间已向$n攻出数掌",
      "force" => 205,
      "attack" => 13,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 17,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "洗剑怀中抱月"
    },
    %{
      "action" => "$N一声清啸，呼的一掌，一招「黄龙转身吐须」，去势奇快，向$n猛击过去",
      "force" => 217,
      "attack" => 17,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 21,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "黄龙转身吐须"
    },
    %{
      "action" => "$N双掌交错，若有若无，一招「上步云边摘月」，自巧转拙，拍向$n的$l",
      "force" => 225,
      "attack" => 22,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 33,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "上步云边摘月"
    },
    %{
      "action" => "$N一招「提撩剑白鹤舒翅」，右手一拳击出，左掌紧跟着在右拳顺势击向$n的$l",
      "force" => 255,
      "attack" => 33,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 41,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "提撩剑白鹤舒翅"
    },
    %{
      "action" => "$N双手齐划，跟着双掌齐推，一招「冲天掌苏秦背剑」，一股排山般掌力直扑$n",
      "force" => 267,
      "attack" => 36,
      "parry" => 30,
      "dodge" => 28,
      "damage" => 49,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "冲天掌苏秦背剑"
    }
  ]

  @impl true
  def id(), do: "chongtian-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 90}

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
      "zhan" => Kantele.Combat.Skills.Performs.ChongtianZhang.Zhan
    }
  end
end

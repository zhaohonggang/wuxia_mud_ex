defmodule Kantele.Combat.Skills.LiuheQuan do
  @moduledoc """
  武学实装「liuhe-quan」（源 liuhe-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/liuhe_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N马步一立，身子微曲，暗喝一声，一招「猫蹿」，一拳直捅$n的$l",
      "force" => 30,
      "attack" => 4,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 4,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "猫蹿"
    },
    %{
      "action" => "$N哈哈一笑，左拳由下至上，右拳平平击出，一招「兔滚」，交替打向$n",
      "force" => 45,
      "attack" => 6,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 6,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "兔滚"
    },
    %{
      "action" => "$N对$n一声大喝，使一招「鹰翻」，左拳击出，随即右拳跟上，两重力道打向$n的$l",
      "force" => 57,
      "attack" => 7,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 11,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "鹰翻"
    },
    %{
      "action" => "$N闷喝一声，双拳向上分开，一记「鹞子翻身」，拳划弧线，左右同时击向$n的$l",
      "force" => 65,
      "attack" => 9,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 14,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "鹞子翻身"
    },
    %{
      "action" => "$N施出「细胸巧」，一声大吼，一拳凌空打出，拳风直逼$n的$l",
      "force" => 85,
      "attack" => 13,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 19,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "细胸巧"
    },
    %{
      "action" => "$N一声长啸，双拳交错击出，一招「跺子脚」，拳风密布$n的前后左右",
      "force" => 97,
      "attack" => 16,
      "parry" => 30,
      "dodge" => 28,
      "damage" => 21,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "跺子脚"
    },
    %{
      "action" => "$N怒吼一声，凌空飞起，一式「松子灵」，双拳居高临下，齐齐捶向$n",
      "force" => 115,
      "attack" => 17,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 24,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "松子灵"
    }
  ]

  @impl true
  def id(), do: "liuhe-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry", "unarmed"]

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

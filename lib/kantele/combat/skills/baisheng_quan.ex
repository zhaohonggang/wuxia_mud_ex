defmodule Kantele.Combat.Skills.BaishengQuan do
  @moduledoc """
  武学实装「baisheng-quan」（源 baisheng-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/baisheng_quan/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N马步一立，身子微曲，暗喝一声，一招「猫蹿」，一拳直捅$n的$l",
      "force" => 130,
      "attack" => 14,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 4,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "猫蹿"
    },
    %{
      "action" => "$N哈哈一笑，左拳由下至上，右拳平平击出，一招「兔滚」，交替打向$n",
      "force" => 145,
      "attack" => 16,
      "parry" => 17,
      "dodge" => 18,
      "damage" => 6,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "兔滚"
    },
    %{
      "action" => "$N对$n一声大喝，使一招「鹰翻」，左拳击出，随即右拳跟上，两重力道打向$n的$l",
      "force" => 157,
      "attack" => 17,
      "parry" => 19,
      "dodge" => 16,
      "damage" => 11,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "鹰翻"
    },
    %{
      "action" => "$N闷喝一声，双拳向上分开，一记「鹞子翻身」，拳划弧线，左右同时击向$n的$l",
      "force" => 165,
      "attack" => 19,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 14,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "鹞子翻身"
    },
    %{
      "action" => "$N施出「细胸巧」，一声大吼，一拳凌空打出，拳风直逼$n的$l",
      "force" => 185,
      "attack" => 33,
      "parry" => 28,
      "dodge" => 24,
      "damage" => 19,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "细胸巧"
    },
    %{
      "action" => "$N一声长啸，双拳交错击出，一招「跺子脚」，拳风密布$n的前后左右",
      "force" => 197,
      "attack" => 36,
      "parry" => 30,
      "dodge" => 28,
      "damage" => 21,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "跺子脚"
    },
    %{
      "action" => "$N怒吼一声，凌空飞起，一式「松子灵」，双拳居高临下，齐齐捶向$n",
      "force" => 285,
      "attack" => 47,
      "parry" => 21,
      "dodge" => 24,
      "damage" => 24,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "松子灵"
    }
  ]

  @impl true
  def id(), do: "baisheng-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 34}

  # LPC `valid_learn(object me)`（源 baisheng-quan.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练百胜神拳必须空手。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候不够，无法学百胜神拳。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练百胜神拳。\n"}

      Stats.skill(stats, "cuff") < 40 ->
        {:error, "你的基本拳脚火候太浅。\n"}

      Stats.skill(stats, "cuff") < lvl ->
        {:error, "你的基本拳脚水平有限，无法领会更高深的百胜神拳。\n"}

      true ->
        :ok
    end
  end

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
      "kai" => Kantele.Combat.Skills.Performs.BaishengQuan.Kai
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

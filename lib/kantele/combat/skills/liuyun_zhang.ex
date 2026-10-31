defmodule Kantele.Combat.Skills.LiuyunZhang do
  @moduledoc """
  武学实装「liuyun-zhang」（源 liuyun-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/liuyun_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「天马行空」，右掌一翻，向$n的$l拍去",
      "force" => 90,
      "attack" => 4,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "天马行空"
    },
    %{
      "action" => "$N使一招「探手截流」，右手斜出，劈向$n的$l",
      "force" => 110,
      "attack" => 6,
      "parry" => 30,
      "dodge" => 48,
      "damage" => 40,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "探手截流"
    },
    %{
      "action" => "$N双手带风，一式「风吹云散」，掌力浑厚，击向$n的$l",
      "force" => 120,
      "attack" => 10,
      "parry" => 60,
      "dodge" => 50,
      "damage" => 48,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "风吹云散"
    },
    %{
      "action" => "$N双手微抬，左右齐出，一招「云深雾锁」，已将$n$l笼罩",
      "force" => 150,
      "attack" => 12,
      "parry" => 71,
      "dodge" => 44,
      "damage" => 55,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "云深雾锁"
    },
    %{
      "action" => "$N双掌翻腾，掌风凌厉，一式「云雾缭绕」，飘然不定，击向$n$l",
      "force" => 180,
      "attack" => 15,
      "parry" => 60,
      "dodge" => 55,
      "damage" => 60,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "云雾缭绕"
    },
    %{
      "action" => "$N双掌拍出，一式「顺流逆流」，掌法一快一慢，向$n的$l打去",
      "force" => 210,
      "attack" => 15,
      "parry" => 62,
      "dodge" => 60,
      "damage" => 70,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "顺流逆流"
    },
    %{
      "action" => "$N快步向前，身法陡快，一招「行云流水」，掌风已到$n$l",
      "force" => 240,
      "attack" => 18,
      "parry" => 71,
      "dodge" => 80,
      "damage" => 80,
      "lvl" => 110,
      "damage_type" => "瘀伤",
      "skill_name" => "行云流水"
    },
    %{
      "action" => "$N双掌下垂，似是无力，但又猛然加快，似攻非攻，一式「流水无情」\\n",
      "force" => 280,
      "attack" => 25,
      "parry" => 80,
      "dodge" => 76,
      "damage" => 90,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "流水无情"
    }
  ]

  @impl true
  def id(), do: "liuyun-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 60}

  # LPC `valid_learn(object me)`（源 liuyun-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练流云掌必须空手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，无法学流云掌。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力太弱，无法练流云掌。\n"}

      Stats.skill(stats, "strike") < 80 ->
        {:error, "你的基本掌法火候太浅。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的流云掌。\n"}

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
      "die" => Kantele.Combat.Skills.Performs.LiuyunZhang.Die,
      "pai" => Kantele.Combat.Skills.Performs.LiuyunZhang.Pai
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

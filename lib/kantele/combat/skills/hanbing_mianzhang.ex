defmodule Kantele.Combat.Skills.HanbingMianzhang do
  @moduledoc """
  武学实装「hanbing-mianzhang」（源 hanbing-mianzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/hanbing_mianzhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.PoisonHit

  @actions [
    %{
      "action" => "$N一式「大江东去」，双掌大开大合，直向$n的$l击去",
      "force" => 100,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "大江东去"
    },
    %{
      "action" => "$N身形一变，一式「黄河九曲」，双掌似曲似直，拍向$n的$l",
      "force" => 130,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "黄河九曲"
    },
    %{
      "action" => "$N使一式「湖光山色」，左掌如微风拂面，右掌似细雨缠身，直取$n的$l",
      "force" => 160,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "湖光山色"
    },
    %{
      "action" => "$N两掌一分，一式「曾经沧海」，隐隐发出潮声，向$n横击过去",
      "force" => 180,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "曾经沧海"
    },
    %{
      "action" => "$N身形一转，使出一式「水光潋滟」，只见漫天掌影罩住了$n的全身",
      "force" => 210,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "水光潋滟"
    },
    %{
      "action" => "$N突然身形一缓，使出一式「小雨初晴」，左掌凝重，右掌轻盈，击往$n的$l",
      "force" => 250,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "小雨初晴"
    },
    %{
      "action" => "$N使一式「风雪江山」，双掌挟狂风暴雪之势，猛地劈向$n的$l",
      "force" => 280,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "风雪江山"
    },
    %{
      "action" => "$N一招「霜华满地」，双掌带着萧瑟的秋气，拍向$n的$l",
      "force" => 300,
      "attack" => 0,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 60,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "霜华满地"
    },
    %{
      "action" => "$N身法陡然一变，使出一式「仙乡冰舸」，掌影千变万幻，令$n无法躲闪",
      "force" => 320,
      "attack" => 0,
      "parry" => 45,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "仙乡冰舸"
    },
    %{
      "action" => "$N清啸一声，一式「冰霜雪雨」，双掌挥舞，如同雪花随风而转，击向$n的$l",
      "force" => 330,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 45,
      "damage" => 100,
      "lvl" => 180,
      "damage_type" => "瘀伤",
      "skill_name" => "冰霜雪雨"
    }
  ]

  @impl true
  def id(), do: "hanbing-mianzhang"

  # LPC hit_ob：lvl>=80 且 jiali>=10 且 damage!=0，`jiali*2 + random(lvl)`
  # 压过对手 force 时上「寒冰掌毒」（duration = lvl/50 + random(lvl/20)）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    PoisonHit.strike(attacker, victim, damage, rng,
      skill: id(),
      cnd: "ice_poison",
      msg: "$n忽然神色大变，一个寒战，退了几步。\n"
    )
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  # LPC valid_learn：空手 / force>=120 / max_neili>=800 / strike>=80 且 >=本技能。
  # 空手检查未建模（character 快照不含持械，见 MEMORY）。

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 54}

  # LPC `valid_learn(object me)`（源 hanbing-mianzhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练寒冰绵掌必须空手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，无法练寒冰绵掌。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力太弱，无法练寒冰绵掌。\n"}

      Stats.skill(stats, "strike") < 80 ->
        {:error, "你的基本掌法火候不够，无法练寒冰绵掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的寒冰绵掌。\n"}

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
      "jue" => Kantele.Combat.Skills.Performs.HanbingMianzhang.Jue
    }
  end
end

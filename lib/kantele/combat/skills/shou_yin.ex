defmodule Kantele.Combat.Skills.ShouYin do
  @moduledoc """
  武学实装「shou-yin」（源 shou-yin.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/shou_yin/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「莲花合掌印」，双掌做锥，直直刺向$n的前胸",
      "force" => 589,
      "attack" => 285,
      "parry" => 189,
      "dodge" => 167,
      "damage" => 303,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「合掌观音印」，飞身跃起，双手如勾，抓向$n的$l",
      "force" => 621,
      "attack" => 309,
      "parry" => 197,
      "dodge" => 188,
      "damage" => 326,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「准提佛母印」，运力于指，直取$n的$l",
      "force" => 642,
      "attack" => 321,
      "parry" => 203,
      "dodge" => 197,
      "damage" => 339,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「红阎婆罗印」，怒吼一声，一掌当头拍向$n的$l",
      "force" => 657,
      "attack" => 335,
      "parry" => 227,
      "dodge" => 215,
      "damage" => 356,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N使出一招「药师佛根本印」，猛冲向前，掌刀如游龙般砍向$n",
      "force" => 673,
      "attack" => 357,
      "parry" => 236,
      "dodge" => 243,
      "damage" => 367,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N使出一招「威德金刚印」，伏身疾进，双掌自下扫向$n的$l",
      "force" => 672,
      "attack" => 371,
      "parry" => 257,
      "dodge" => 265,
      "damage" => 386,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N使出一招「上乐金刚印」，飞身横跃，双掌前后击出，抓向$n的咽",
      "force" => 680,
      "attack" => 398,
      "parry" => 271,
      "dodge" => 297,
      "damage" => 403,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「六臂智慧印」，顿时劲气弥漫，天空中出现无数掌影打",
      "force" => 720,
      "attack" => 435,
      "parry" => 287,
      "dodge" => 315,
      "damage" => 436,
      "lvl" => 0,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "shou-yin"

  # LPC hit_ob：damage_bonus>=100 且 bonus/5 > 对手 str 时追加掌印创伤
  @impl true
  def hit_ob(_attacker, victim, damage_bonus, _factor, _rng) do
    if damage_bonus >= 100 and div(damage_bonus, 5) > Map.get(victim, :str, 0) do
      {div(damage_bonus - 100, 2),
       "只听$n一声闷哼，一双手印重重的印在胸前，“哇”的喷出了一大口鲜血！\n"}
    else
      {0, nil}
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 300, neili: 300}

  # LPC `valid_learn(object me)`（源 shou-yin.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练手印必须空手。\n"}

      Stats.int(stats) < 36 ->
        {:error, "你觉得手印过于艰深，难以理解。\n"}

      Stats.skill(stats, "martial-cognize") < 300 ->
        {:error, "你的武学修养太低，无法修习手印。\n"}

      not is_nil(max_neili) and max_neili < 5000 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 350 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "hand") < 200 ->
        {:error, "你的基本手法火候太浅。\n"}

      Stats.skill(stats, "hand") < lvl ->
        {:error, "你的基本手法水平有限，无法领会更高深的手印。\n"}

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

  @impl true
  def perform_list() do
    %{
      "jie" => Kantele.Combat.Skills.Performs.ShouYin.Jie
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

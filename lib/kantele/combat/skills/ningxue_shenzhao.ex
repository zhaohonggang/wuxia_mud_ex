defmodule Kantele.Combat.Skills.NingxueShenzhao do
  @moduledoc """
  武学实装「ningxue-shenzhao」（源 ningxue-shenzhao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/ningxue_shenzhao/
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.PoisonHit

  @actions [
    %{
      "action" => "$N全身拔地而起，半空中一个筋斗，一式「凶鹰袭兔」，迅猛地抓向$n的$l",
      "force" => 250,
      "attack" => 45,
      "parry" => 18,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "凶鹰袭兔"
    },
    %{
      "action" => "$N单腿直立，双臂平伸，一式「雄鹰展翅」，双爪一前一后拢向$n的$l",
      "force" => 270,
      "attack" => 50,
      "parry" => 26,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "雄鹰展翅"
    },
    %{
      "action" => "$N一式「拔翅鹰飞」，全身向斜里平飞，右腿一绷，双爪搭向$n的肩头",
      "force" => 300,
      "attack" => 60,
      "parry" => 32,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "抓伤",
      "skill_name" => "拔翅鹰飞"
    },
    %{
      "action" => "$N双爪交错上举，使一式「迎风振翼」，一拔身，分别袭向$n左右腋空门",
      "force" => 340,
      "attack" => 85,
      "parry" => 55,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "抓伤",
      "skill_name" => "迎风振翼"
    },
    %{
      "action" => "$N全身滚动上前，一式「飞龙献爪」，右爪突出，鬼魅般抓向$n的胸口",
      "force" => 350,
      "attack" => 110,
      "parry" => 68,
      "dodge" => 40,
      "damage" => 76,
      "lvl" => 120,
      "damage_type" => "抓伤",
      "skill_name" => "飞龙献爪"
    },
    %{
      "action" => "$N伏地滑行，一式「顶天立地」，上手袭向膻中大穴，下手反抓$n的裆部",
      "force" => 370,
      "attack" => 121,
      "parry" => 78,
      "dodge" => 51,
      "damage" => 96,
      "lvl" => 140,
      "damage_type" => "抓伤",
      "skill_name" => "顶天立地"
    },
    %{
      "action" => "$N左右手掌爪互逆，一式「搏击长空」，无数道劲气破空而出，迅疾无比地击向$n",
      "force" => 398,
      "attack" => 133,
      "parry" => 85,
      "dodge" => 67,
      "damage" => 107,
      "lvl" => 160,
      "damage_type" => "抓伤",
      "skill_name" => "搏击长空"
    },
    %{
      "action" => "$N腾空高飞三丈，一式「鹰扬万里」，天空中顿时显出一个巨灵爪影，缓缓罩向$n",
      "force" => 410,
      "attack" => 143,
      "parry" => 81,
      "dodge" => 55,
      "damage" => 121,
      "lvl" => 180,
      "damage_type" => "抓伤",
      "skill_name" => "鹰扬万里"
    },
    %{
      "action" => "$N忽的拨地而起，使一式「苍龙出水」，身形化作一道闪电射向$n",
      "force" => 431,
      "attack" => 162,
      "parry" => 86,
      "dodge" => 63,
      "damage" => 133,
      "lvl" => 200,
      "damage_type" => "内伤",
      "skill_name" => "苍龙出水"
    },
    %{
      "action" => "$N微微一笑，使一式「万佛朝宗」，双手幻出万道金光,直射向$n的$l",
      "force" => 455,
      "attack" => 173,
      "parry" => 95,
      "dodge" => 66,
      "damage" => 137,
      "lvl" => 220,
      "damage_type" => "内伤",
      "skill_name" => "万佛朝宗"
    }
  ]

  @impl true
  def id(), do: "ningxue-shenzhao"

  # LPC hit_ob：lvl>=80 且 jiali>=10 且 damage!=0，`jiali*2 + random(lvl)`
  # 压过对手 force 时上「凝血之扰」（duration = lvl/100 + random(lvl/10)）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    PoisonHit.strike(attacker, victim, damage, rng,
      skill: id(),
      cnd: "ningxue_shenzhao",
      msg: "只听$n一声惨嚎，看来受到了凝血神爪毒劲的干扰！\n",
      div1: 100,
      div2: 10
    )
  end

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  # LPC valid_learn：空手 / max_neili>=800 / str>=40 / dex>=40 / force>=200 /
  # claw>=180 且 >=本技能。空手检查未建模（character 快照不含持械，见 MEMORY）。

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 300}

  # LPC `valid_learn(object me)`（源 ningxue-shenzhao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练凝血神爪必须空手。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力太弱，无法练凝血神爪。\n"}

      Stats.query_str(stats) < 40 ->
        {:error, "你现在膂力孱弱，还无法练凝血神爪。\n"}

      Stats.query_dex(stats) < 40 ->
        {:error, "你现在身法欠佳，还无法练凝血神爪。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功太差，无法练凝血神爪。\n"}

      Stats.skill(stats, "claw") < 180 ->
        {:error, "你的基本爪法太差，无法领会凝血神爪。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本爪法火候不够，无法领会更高深的凝血神爪。\n"}

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
      "ji" => Kantele.Combat.Skills.Performs.NingxueShenzhao.Ji
    }
  end
end

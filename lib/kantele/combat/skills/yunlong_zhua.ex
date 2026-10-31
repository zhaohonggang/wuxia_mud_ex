defmodule Kantele.Combat.Skills.YunlongZhua do
  @moduledoc """
  武学实装「yunlong-zhua」（源 yunlong-zhua.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/yunlong_zhua/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N全身拔地而起，半空中一个筋斗，一式「凶鹰袭兔」，迅猛地抓向$n的$l",
      "force" => 70,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N单腿直立，双臂平伸，一式「雄鹰展翅」，双爪一前一后拢向$n的$l",
      "force" => 90,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N一式「拔翅鹰飞」，全身向斜里平飞，右腿一绷，双爪搭向$n的肩头",
      "force" => 100,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双爪交错上举，使一式「迎风振翼」，一拔身，分别袭向$n左右腋空门",
      "force" => 120,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N全身滚动上前，一式「飞龙献爪」，右爪突出，鬼魅般抓向$n的胸口",
      "force" => 140,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N伏地滑行，一式「顶天立地」，上手袭向膻中大穴，下手反抓$n的裆部",
      "force" => 150,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 35,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左右手掌爪互逆，一式「搏击长空」，无数道劲气破空而出，迅疾无比地击向$n",
      "force" => 180,
      "attack" => 0,
      "parry" => 55,
      "dodge" => 55,
      "damage" => 65,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N腾空高飞三丈，一式「鹰扬万里」，天空中顿时显出一个巨灵爪影，缓缓罩向$n",
      "force" => 230,
      "attack" => 0,
      "parry" => 40,
      "dodge" => 40,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N忽的拨地而起，使一式「苍龙出水」，身形化作一道闪电射向$n",
      "force" => 270,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 50,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N微微一笑，使一式「万佛朝宗」，双手幻出万道金光,直射向$n的$l",
      "force" => 310,
      "attack" => 0,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 100,
      "lvl" => 180,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "yunlong-zhua"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 62}

  # LPC `valid_learn(object me)`（源 yunlong-zhua.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练云龙爪必须空手。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的云龙神功火候不够，无法学云龙爪。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力太弱，无法练云龙爪。\n"}

      Stats.skill(stats, "claw") < 100 ->
        {:error, "你的基本爪法火候不够，无法学云龙爪。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本爪法水平有限，无法继续学云龙爪。\n"}

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

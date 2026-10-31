defmodule Kantele.Combat.Skills.ChansiShou do
  @moduledoc """
  武学实装「chansi-shou」（源 chansi-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/chansi_shou/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N以掌化爪，五指如钩，直逼$n的膻中要穴",
      "force" => 90,
      "attack" => 25,
      "parry" => 40,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手虚晃，右手上下直击，反扣$n的肩井大穴",
      "force" => 120,
      "attack" => 32,
      "parry" => 42,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N掌指齐出，拍拿并施，拿向$n的三路要害",
      "force" => 150,
      "attack" => 41,
      "parry" => 45,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手鹰抓，右手蛇举，疾扣$n的中节大脉",
      "force" => 180,
      "attack" => 45,
      "parry" => 46,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N上前一步，四面八方出现无数掌影，一爪抓向$n的胸口",
      "force" => 220,
      "attack" => 53,
      "parry" => 54,
      "dodge" => 25,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N两手环扣，全身关节啪啪作响，击向$n的$l",
      "force" => 270,
      "attack" => 58,
      "parry" => 58,
      "dodge" => 30,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N十指齐伸，遮天蔽日般地笼罩$n的全身要穴",
      "force" => 330,
      "attack" => 70,
      "parry" => 62,
      "dodge" => 35,
      "damage" => 70,
      "lvl" => 160,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N岳立霆峙，在一阵暴雷声中，双手同时拍向$n的全身各处",
      "force" => 360,
      "attack" => 77,
      "parry" => 65,
      "dodge" => 50,
      "damage" => 80,
      "lvl" => 180,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "chansi-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 69}

  # LPC `valid_learn(object me)`（源 chansi-shou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练缠丝擒拿手必须空手。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学缠丝擒拿手。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力修为太弱，无法练缠丝擒拿手。\n"}

      Stats.skill(stats, "hand") < 80 ->
        {:error, "你的基本手法不够，无法练缠丝擒拿手。\n"}

      Stats.skill(stats, "hand") < lvl ->
        {:error, "你的基本手法水平有限，无法领会更高深的缠丝擒拿手。\n"}

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
      "qin" => Kantele.Combat.Skills.Performs.ChansiShou.Qin
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

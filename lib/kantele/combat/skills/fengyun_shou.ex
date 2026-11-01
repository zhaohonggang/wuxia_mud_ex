defmodule Kantele.Combat.Skills.FengyunShou do
  @moduledoc """
  风云手（对照 `kungfu/skill/fengyun-shou.c`）

  手法载体：`valid_enable("hand")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/fengyun_shou/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、max_neili>=200，本版以 force>=40 代理；
  - LPC `valid_combine("yingzhua-gong")` 合璧用法未建模；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一式「风满长空」，以掌化爪，五指如钩，直逼$n的膻中要穴",
      "force" => 90,
      "attack" => 25,
      "dodge" => 5,
      "parry" => 40,
      "damage" => 15,
      "lvl" => 0,
      "skill_name" => "风满长空"
    },
    %{
      "action" => "$N左手虚晃，一式「烈火腾云」，右手上下直击，反扣$n的肩井大穴",
      "force" => 120,
      "attack" => 32,
      "dodge" => 10,
      "parry" => 42,
      "damage" => 20,
      "lvl" => 30,
      "skill_name" => "烈火腾云"
    },
    %{
      "action" => "$N使一式「草深雾泽」，掌指齐出，拍拿并施，拿向$n的三路要害",
      "force" => 150,
      "attack" => 41,
      "dodge" => 15,
      "parry" => 45,
      "damage" => 30,
      "lvl" => 60,
      "skill_name" => "草深雾泽"
    },
    %{
      "action" => "$N左手鹰抓，右手蛇举，一式「天目昭辉」疾扣$n的中节大脉",
      "force" => 180,
      "attack" => 45,
      "dodge" => 20,
      "parry" => 46,
      "damage" => 40,
      "lvl" => 90,
      "skill_name" => "天目昭辉"
    },
    %{
      "action" => "$N使一式「雷震四方」，四面八方出现无数掌影，一爪突出，抓向$n的胸口",
      "force" => 220,
      "attack" => 53,
      "dodge" => 25,
      "parry" => 54,
      "damage" => 50,
      "lvl" => 120,
      "skill_name" => "雷震四方"
    },
    %{
      "action" => "$N两手环扣，全身关节啪啪作响，一式「水到渠成」，击向$n的$l",
      "force" => 270,
      "attack" => 58,
      "dodge" => 30,
      "parry" => 58,
      "damage" => 60,
      "lvl" => 140,
      "skill_name" => "水到渠成"
    },
    %{
      "action" => "$N一式「山高林密」，十指齐伸，遮天蔽日般地笼罩$n的全身要穴",
      "force" => 330,
      "attack" => 70,
      "dodge" => 35,
      "parry" => 62,
      "damage" => 70,
      "lvl" => 160,
      "skill_name" => "山高林密"
    },
    %{
      "action" => "$N岳立霆峙，一式「地老天荒」，在一阵暴雷声中，双手同时拍向$n的七道死穴",
      "force" => 360,
      "attack" => 77,
      "dodge" => 50,
      "parry" => 65,
      "damage" => 80,
      "lvl" => 180,
      "skill_name" => "地老天荒"
    }
  ]

  @impl true
  def id(), do: "fengyun-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 fengyun-shou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练风云手必须空手。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候不够，无法学风云手。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力太弱，无法练风云手。\n"}

      Stats.skill(stats, "hand") < lvl ->
        {:error, "你的基本手法水平有限，无法领会更高深的风云手。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"qinna" => Kantele.Combat.Skills.Performs.FengyunShou.Qinna}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

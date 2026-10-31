defmodule Kantele.Combat.Skills.JindingZhang do
  @moduledoc """
  武学实装「jinding-zhang」（源 jinding-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/jinding_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形微晃，一招「三阳开泰」，掌起风生，$n只觉得一股暖气袭向$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "三阳开泰"
    },
    %{
      "action" => "$N双手变幻，五指轻弹，一招「五气呈祥」，力分五路，招罩十方，抓向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "五气呈祥"
    },
    %{
      "action" => "$N左手前引，右手倏出，抢在头里，一招「罡风推云」，疾抓向$n的$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "罡风推云"
    },
    %{
      "action" => "$N左手圈转，轻拂$n的左手，反向推出，一招「逆流捧沙」，猛地击向$n的下巴",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "逆流捧沙"
    },
    %{
      "action" => "$N舌绽春雷，一声娇喝，在$n一愣间，右手一招「雷洞霹雳」，直捣$n的$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "内伤",
      "skill_name" => "雷洞霹雳"
    },
    %{
      "action" => "$N双手平举握拳，一招「金顶佛光」施出，掌影重重，难辨虚实，掌风已经袭面",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 70,
      "damage_type" => "内伤",
      "skill_name" => "金顶佛光"
    },
    %{
      "action" => "$N一幅宝像庄严，使出「梵心降魔」，掌势如虹，绕着$n漂移不定",
      "force" => 230,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "梵心降魔"
    },
    %{
      "action" => "$N双臂疾舞，化为点点掌影，一招「法尊八荒」铺天盖地袭向$n全身各处大穴",
      "force" => 260,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "法尊八荒"
    }
  ]

  @impl true
  def id(), do: "jinding-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 48}

  # LPC `valid_learn(object me)`（源 jinding-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练金顶绵掌必须空手。\n"}

      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候不够，不能练金顶绵掌。\n"}

      not is_nil(max_neili) and max_neili < 150 ->
        {:error, "你的内力太弱，无法练金顶绵掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法太差，无法领会更高深的金顶绵掌。\n"}

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
      "bashi" => Kantele.Combat.Skills.Performs.JindingZhang.Bashi
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

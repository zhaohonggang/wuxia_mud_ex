defmodule Kantele.Combat.Skills.YinsuoJinling do
  @moduledoc """
  武学实装「yinsuo-jinling」（源 yinsuo-jinling.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yinsuo_jinling/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N端坐不动，一招「对台梳妆」，手中$w抖得笔直，对准$n$l直刺而去",
      "force" => 80,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 35,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "对台梳妆"
    },
    %{
      "action" => "$N身形一转，一招「云龙白鹤」，手中$w如矫龙般腾空一卷，猛地向$n劈头打下",
      "force" => 130,
      "attack" => 38,
      "parry" => 27,
      "dodge" => 43,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "抽伤",
      "skill_name" => "云龙白鹤"
    },
    %{
      "action" => "$N力贯鞭梢，一招「明月千里」，手中$w舞出满天鞭影，铺天盖地袭向$n全身",
      "force" => 160,
      "attack" => 45,
      "parry" => 29,
      "dodge" => 63,
      "damage" => 61,
      "lvl" => 80,
      "damage_type" => "抽伤",
      "skill_name" => "明月千里"
    },
    %{
      "action" => "$N一声娇喝，一招「映月无声」，手中$w变换莫测，从意想不到的方位扫向$n",
      "force" => 180,
      "attack" => 50,
      "parry" => 33,
      "dodge" => 65,
      "damage" => 68,
      "lvl" => 120,
      "damage_type" => "抽伤",
      "skill_name" => "映月无声"
    },
    %{
      "action" => "$N飞身一跃而起，凌空一招「影玉徵辉」，$w宛如蛟龙通天，携着飕飕破空之声袭向$n",
      "force" => 210,
      "attack" => 53,
      "parry" => 36,
      "dodge" => 76,
      "damage" => 73,
      "lvl" => 160,
      "damage_type" => "抽伤",
      "skill_name" => "影玉徵辉"
    },
    %{
      "action" => "$N身形飘逸无定，一招「金光泻地」，手中$w幻出无数鞭影，笼罩$n全身",
      "force" => 230,
      "attack" => 65,
      "parry" => 35,
      "dodge" => 92,
      "damage" => 91,
      "lvl" => 180,
      "damage_type" => "抽伤",
      "skill_name" => "金光泻地"
    },
    %{
      "action" => "$N身形飘逸无定，一招「蜃楼银沙」，手中$w幻出无数鞭影，笼罩$n全身",
      "force" => 251,
      "attack" => 66,
      "parry" => 40,
      "dodge" => 117,
      "damage" => 120,
      "lvl" => 200,
      "damage_type" => "抽伤",
      "skill_name" => "蜃楼银沙"
    }
  ]

  @impl true
  def id(), do: "yinsuo-jinling"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 55}

  # LPC `valid_learn(object me)`（源 yinsuo-jinling.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)

    cond do
      gender != "女性" ->
        {:error, "银索金铃只有女性能练。\n"}

      Stats.dex(stats) < 28 ->
        {:error, "你的先天身法不够，无法练银索金铃。\n"}

      (not (Skill.wielding?(character))) or (Skill.wielded_skill_type(character) != "whip") ->
        {:error, "你必须先找一条鞭子才能练银索金铃。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不足，没有办法练银索金铃。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅，没有办法练银索金铃。\n"}

      Stats.skill(stats, "whip") < 30 ->
        {:error, "你的基本鞭法火候太浅，没有办法练银索金铃。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的银索金铃。\n"}

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
      "dian" => Kantele.Combat.Skills.Performs.YinsuoJinling.Dian,
      "feng" => Kantele.Combat.Skills.Performs.YinsuoJinling.Feng,
      "kai" => Kantele.Combat.Skills.Performs.YinsuoJinling.Kai
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"
end

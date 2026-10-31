defmodule Kantele.Combat.Skills.JiuyinBaiguzhao do
  @moduledoc """
  武学实装「jiuyin-baiguzhao」（源 jiuyin-baiguzhao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/jiuyin_baiguzhao/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左爪虚晃，右爪蓄力，一招「勾魂夺魄」直插向$n的$l",
      "force" => 250,
      "attack" => 45,
      "parry" => 18,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "勾魂夺魄"
    },
    %{
      "action" => "$N双手连环成爪，爪爪钩向$n，「九子连环」已向$n的$l抓出",
      "force" => 270,
      "attack" => 50,
      "parry" => 26,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "九子连环"
    },
    %{
      "action" => "$N双手使出「十指穿心」，招招不离$n的$l",
      "force" => 300,
      "attack" => 60,
      "parry" => 32,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "抓伤",
      "skill_name" => "九子连环"
    },
    %{
      "action" => "$N身形围$n一转，使出「天罗地网」，$n的$l已完全笼罩在爪影下",
      "force" => 340,
      "attack" => 85,
      "parry" => 55,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "抓伤",
      "skill_name" => "天罗地网"
    },
    %{
      "action" => "$N使一招「风卷残云」，双爪幻出满天爪影抓向$n全身",
      "force" => 370,
      "attack" => 110,
      "parry" => 68,
      "dodge" => 40,
      "damage" => 70,
      "lvl" => 130,
      "damage_type" => "抓伤",
      "skill_name" => "风卷残云"
    },
    %{
      "action" => "$N吐气扬声，一招「唯我独尊」双爪奋力向$n天灵戳下",
      "force" => 420,
      "attack" => 140,
      "parry" => 85,
      "dodge" => 50,
      "damage" => 90,
      "lvl" => 160,
      "damage_type" => "抓伤",
      "skill_name" => "唯我独尊"
    }
  ]

  @impl true
  def id(), do: "jiuyin-baiguzhao"

  # LPC hit_ob：damage_bonus>=100 且 bonus/5 > 对手 str 时追加骨骼碎裂创伤
  @impl true
  def hit_ob(_attacker, victim, damage_bonus, _factor, _rng) do
    if damage_bonus >= 100 and div(damage_bonus, 5) > Map.get(victim, :str, 0) do
      {div(damage_bonus - 100, 2), "你听到「咔嚓」一声脆响，竟像是骨骼碎裂的声音！\n"}
    else
      {0, nil}
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 250}

  # LPC `valid_learn(object me)`（源 jiuyin-baiguzhao.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练九阴白骨爪必须空手。\n"}

      not is_nil(max_neili) and max_neili < 800 ->
        {:error, "你的内力太弱，无法练九阴白骨爪。\n"}

      Stats.query_str(stats) < 30 ->
        {:error, "你现在膂力孱弱，还无法练九阴白骨爪。\n"}

      Stats.skill(stats, "force") < 90 ->
        {:error, "你的内功太差，无法练九阴白骨爪。\n"}

      Stats.skill(stats, "claw") < 60 ->
        {:error, "你的基本爪法太差，无法领会九阴白骨爪。\n"}

      Stats.skill(stats, "claw") < lvl ->
        {:error, "你的基本爪法火候不够，无法领会更高深的九阴白骨爪。\n"}

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
      "duo" => Kantele.Combat.Skills.Performs.JiuyinBaiguzhao.Duo,
      "zhua" => Kantele.Combat.Skills.Performs.JiuyinBaiguzhao.Zhua
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

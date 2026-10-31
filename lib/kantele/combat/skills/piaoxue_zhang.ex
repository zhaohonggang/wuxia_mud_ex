defmodule Kantele.Combat.Skills.PiaoxueZhang do
  @moduledoc """
  武学实装「piaoxue-zhang」（源 piaoxue-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/piaoxue_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N划身错步，一式「追风逐电」，双掌内拢外托，同时攻向$n的左肩",
      "force" => 170,
      "attack" => 85,
      "parry" => 38,
      "dodge" => 38,
      "damage" => 36,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "追风逐电"
    },
    %{
      "action" => "$N一式「云飘四海」，双掌虚虚实实，以迅雷不及掩耳之势劈向$n",
      "force" => 210,
      "attack" => 98,
      "parry" => 43,
      "dodge" => 43,
      "damage" => 44,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "云飘四海"
    },
    %{
      "action" => "$N使一式「八方云涌」，劲气弥漫，双掌如轮，一环环向$n的后背斫去",
      "force" => 280,
      "attack" => 103,
      "parry" => 51,
      "dodge" => 51,
      "damage" => 58,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "八方云涌"
    },
    %{
      "action" => "$N一式「龙卷暴伸」，双掌似让非让，似顶非顶，气浪如急流般使$n陷身其中",
      "force" => 340,
      "attack" => 125,
      "parry" => 65,
      "dodge" => 65,
      "damage" => 67,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "龙卷暴伸"
    },
    %{
      "action" => "$N一式「冰封万里」，掌影层层叠叠，飘飘渺渺，凌厉的掌风直涌$n而去",
      "force" => 370,
      "attack" => 131,
      "parry" => 68,
      "dodge" => 68,
      "damage" => 71,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "冰封万里"
    },
    %{
      "action" => "$N双手变幻，五指轻弹，一招「穹寰飞仙」，力分五路，招划十方笼罩$n",
      "force" => 410,
      "attack" => 145,
      "parry" => 73,
      "dodge" => 73,
      "damage" => 82,
      "lvl" => 200,
      "damage_type" => "内伤",
      "skill_name" => "穹寰飞仙"
    }
  ]

  @impl true
  def id(), do: "piaoxue-zhang"

  # LPC hit_ob：damage_bonus>=180 且自身 >=160 级、bonus/6 > 对手 con 时追加断肋创伤
  # （LPC 文案「一跟肋骨」为原样笔误，verbatim 保留）
  @impl true
  def hit_ob(attacker, victim, damage_bonus, _factor, _rng) do
    lvl = Map.get(attacker.skills, "piaoxue-zhang", 0)

    if damage_bonus >= 180 and lvl >= 160 and
         div(damage_bonus, 6) > Map.get(victim, :con, 0) do
      {div(damage_bonus - 140, 3), "只听$n前胸“喀嚓”一声闷响，竟似折断了一跟肋骨。\n"}
    else
      {0, nil}
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 80}

  # LPC `valid_learn(object me)`（源 piaoxue-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练飘雪穿云掌必须空手。\n"}

      Stats.con(stats) < 28 ->
        {:error, "你的先天根骨欠佳，不能练飘雪穿云掌。\n"}

      Stats.str(stats) < 32 ->
        {:error, "你的先天臂力孱弱，不能练飘雪穿云掌。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，不能练飘雪穿云掌。\n"}

      Stats.skill(stats, "strike") < 100 ->
        {:error, "你的掌法根基不够，不能练飘雪穿云掌。\n"}

      not is_nil(max_neili) and max_neili < 2200 ->
        {:error, "你的内力修为太浅，无法练飘雪穿云掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, "sixiang-zhang") ->
        {:error, "你的基本掌法太差，无法领会更高深的飘雪穿云掌。\n"}

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
      "yun" => Kantele.Combat.Skills.Performs.PiaoxueZhang.Yun,
      "zhao" => Kantele.Combat.Skills.Performs.PiaoxueZhang.Zhao
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

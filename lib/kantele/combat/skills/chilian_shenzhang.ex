defmodule Kantele.Combat.Skills.ChilianShenzhang do
  @moduledoc """
  武学实装「chilian-shenzhang」（源 chilian-shenzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/chilian_shenzhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「赤色落阳」，掌力化成弧形，罩向$n的$l",
      "force" => 60,
      "attack" => 2,
      "parry" => 1,
      "dodge" => 0,
      "damage" => 2,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "赤色落阳"
    },
    %{
      "action" => "$N一招「七彩流金」，身体高高跃起，扑向$n的$l就",
      "force" => 80,
      "attack" => 8,
      "parry" => 3,
      "dodge" => 0,
      "damage" => 4,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "七彩流金"
    },
    %{
      "action" => "$N一招「赤蝶迎晚霞」，忽然袖中双掌咋现，分别从",
      "force" => 100,
      "attack" => 12,
      "parry" => 0,
      "dodge" => 43,
      "damage" => 6,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "赤蝶迎晚霞"
    },
    %{
      "action" => "$N一招「群山遮落日」,头缓缓低下，似乎显得没精打",
      "force" => 130,
      "attack" => 15,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 8,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "群山遮落日"
    },
    %{
      "action" => "$N一招「幽幽谷中叙」，突然纵起丈余，犹如一只在空",
      "force" => 150,
      "attack" => 22,
      "parry" => 0,
      "dodge" => 52,
      "damage" => 14,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "幽幽谷中叙"
    },
    %{
      "action" => "$N双掌平挥，一招「冥冥道中聚」身如陀螺急转，忽然",
      "force" => 180,
      "attack" => 23,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "冥冥道中聚"
    },
    %{
      "action" => "$N一招「高堂明镜」，犹如一只展翅翱翔的大鹏，运掌",
      "force" => 210,
      "attack" => 20,
      "parry" => 0,
      "dodge" => 63,
      "damage" => 40,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "高堂明镜"
    },
    %{
      "action" => "$N左掌虚晃，右掌一记「天上人间」猛地插往$n的$l",
      "force" => 240,
      "attack" => 18,
      "parry" => 0,
      "dodge" => 77,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "天上人间"
    },
    %{
      "action" => "$N施出「金石为开」，双掌不断反转，忽地并拢，笔直",
      "force" => 260,
      "attack" => 21,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "金石为开"
    },
    %{
      "action" => "$N施出「万众归心」，双掌翻腾不息，龙吟般的卷向$n",
      "force" => 280,
      "attack" => 25,
      "parry" => 0,
      "dodge" => 81,
      "damage" => 80,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "万众归心"
    }
  ]

  @impl true
  def id(), do: "chilian-shenzhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 61, neili: 53}

  # LPC `valid_learn(object me)`（源 chilian-shenzhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练赤练神掌必须空手。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功火候不够，无法练赤练神掌。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力太弱，无法练赤练神掌。\n"}

      Stats.skill(stats, "strike") < 80 ->
        {:error, "你的基本掌法火候不够，无法练赤练神掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的赤练神掌。\n"}

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
      "lian" => Kantele.Combat.Skills.Performs.ChilianShenzhang.Lian
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

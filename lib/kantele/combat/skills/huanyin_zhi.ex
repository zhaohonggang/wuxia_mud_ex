defmodule Kantele.Combat.Skills.HuanyinZhi do
  @moduledoc """
  武学实装「huanyin-zhi」（源 huanyin-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/huanyin_zhi/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一直戳出，幻起一团指影，逼向$n的$l",
      "force" => 250,
      "attack" => 19,
      "parry" => 22,
      "dodge" => 18,
      "damage" => 28,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N全身之力聚于一指，直指向$n的胸前",
      "force" => 270,
      "attack" => 36,
      "parry" => 31,
      "dodge" => 28,
      "damage" => 35,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "天似无情"
    },
    %{
      "action" => "$N提身却步，右手忽的点出，向$n的$l划过",
      "force" => 290,
      "attack" => 39,
      "parry" => 22,
      "dodge" => 38,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "情根深种"
    },
    %{
      "action" => "$N轻声吐气，双指飞似的刺向$n的额、颈、肩、臂、胸、背",
      "force" => 300,
      "attack" => 47,
      "parry" => 42,
      "dodge" => 35,
      "damage" => 48,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "情在天涯"
    },
    %{
      "action" => "$N左掌掌心向外，右指蓄势点向$n的$l",
      "force" => 330,
      "attack" => 55,
      "parry" => 50,
      "dodge" => 48,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "独饮情伤"
    },
    %{
      "action" => "$N右手伸出，十指叉开，小指拂向$n的太渊穴",
      "force" => 350,
      "attack" => 70,
      "parry" => 60,
      "dodge" => 58,
      "damage" => 60,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "无诉别情"
    }
  ]

  @impl true
  def id(), do: "huanyin-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 72, neili: 69}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  @doc """
  学习门槛（对照 `huanyin-zhi.c` valid_learn）

  - 必须空手
  - `me->query_skill("force") < 200` → 内功（有效等级）
  - `me->query("max_neili") < 800` → vitals
  - `me->query_skill("finger", 1) < 本门` → 执法门槛
  LPC 以 `return 1` 收尾。
  """
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) or Skill.secondary_wielding?(character) ->
        {:error, "练幻阴指法必须空手。\n"}

      Stats.effective(stats, "force") < 200 ->
        {:error, "你的内功火候不够，无法学幻阴指法。\n"}

      not is_integer(max_neili) or max_neili < 800 ->
        {:error, "你的内力太弱，无法练幻阴指法。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本执法水平有限，无法领会更高深的幻阴指法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

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
      "huanyin" => Kantele.Combat.Skills.Performs.HuanyinZhi.Huanyin
    }
  end
end

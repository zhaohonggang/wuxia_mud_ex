defmodule Kantele.Combat.Skills.PaiyunShou do
  @moduledoc """
  武学实装「paiyun-shou」（源 paiyun-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/paiyun_shou/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N跨开马步，右掌前出，十指伸缩，虚虚实实地袭向$n的全身要穴",
      "force" => 30,
      "attack" => 0,
      "parry" => 4,
      "dodge" => 1,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N退后一步，双掌一起排出，如钩如戢，插向$n的$l",
      "force" => 40,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 15,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N忽的一转身，两手环扣，拢成圈状，猛击$n的下颌",
      "force" => 60,
      "attack" => 0,
      "parry" => 7,
      "dodge" => 18,
      "damage" => 10,
      "lvl" => 30,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，戳向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 11,
      "dodge" => 25,
      "damage" => 12,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左手护胸，腋下含空，右手五指如钩，打向$n的要穴",
      "force" => 100,
      "attack" => 0,
      "parry" => 14,
      "dodge" => 30,
      "damage" => 15,
      "lvl" => 50,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N右腿斜上，上手取目，下手反勾$n的裆部",
      "force" => 115,
      "attack" => 0,
      "parry" => 17,
      "dodge" => 35,
      "damage" => 19,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一手虚指$n的剑诀，劈空抓向$n手中的兵刃",
      "force" => 130,
      "attack" => 0,
      "parry" => 13,
      "dodge" => 32,
      "damage" => 21,
      "lvl" => 70,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N左手指向$n胸前的五道大穴，右手斜指太阳穴，两面夹击$n",
      "force" => 150,
      "attack" => 0,
      "parry" => 18,
      "dodge" => 38,
      "damage" => 24,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一手撑天，一手指地，劲气笼罩$n的全身",
      "force" => 170,
      "attack" => 0,
      "parry" => 12,
      "dodge" => 42,
      "damage" => 27,
      "lvl" => 90,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N拳掌招若隐若现，若有若无，缓缓地拍向$n的丹田",
      "force" => 190,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "paiyun-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 37, neili: 25}

  # LPC `valid_learn(object me)`（源 paiyun-shou.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练排云手必须空手。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候不够，无法学排云手。\n"}

      not is_nil(max_neili) and max_neili < 250 ->
        {:error, "你的内力太弱，无法练排云手。\n"}

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

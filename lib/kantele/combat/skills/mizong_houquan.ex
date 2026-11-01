defmodule Kantele.Combat.Skills.MizongHouquan do
  @moduledoc """
  迷踪猴拳（对照 `kungfu/skill/mizong-houquan.c`）

  拳法载体：`valid_enable("cuff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/mizong_houquan/`。

  学习门槛 `valid_learn/2`（max_neili>=1200 / force>=100 / cuff>=100 / cuff>=mizong-houquan）与
  练招消耗 `practice_cost`（LPC 扣 qi 55 / neili 78，须空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「须空手（weapon/secondary_weapon 为空）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N单腿微曲，忽的向前扑出，一式「仙猴摘桃」，二爪直出，抓向$n的双眼",
      "force" => 180,
      "attack" => 41,
      "dodge" => 35,
      "parry" => 35,
      "damage" => 28,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N左手虚晃，一式「灵猴攀枝」，右手直击，反扣$n的肩井大穴",
      "force" => 260,
      "attack" => 53,
      "dodge" => 45,
      "parry" => 45,
      "damage" => 36,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一臂前伸，一臂后指，一式「猿臂轻舒」，攻向$n的两肋",
      "force" => 310,
      "attack" => 64,
      "dodge" => 53,
      "parry" => 53,
      "damage" => 42,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N忽然缩成一团，使一式「八方幻影」，双掌无形无定，一爪抓向$n的胸口",
      "force" => 360,
      "attack" => 75,
      "dodge" => 61,
      "parry" => 61,
      "damage" => 52,
      "lvl" => 90,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N猛吸一口气，一弯腰，使一式「水中揽月」，双爪疾扣向$n的小腹",
      "force" => 430,
      "attack" => 84,
      "dodge" => 65,
      "parry" => 65,
      "damage" => 58,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N猛的向上高高跃起，一式「落地摘星」，居高临下，一爪罩向$n的头骨",
      "force" => 460,
      "attack" => 91,
      "dodge" => 67,
      "parry" => 69,
      "damage" => 65,
      "lvl" => 150,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "mizong-houquan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  # LPC valid_learn 要求 max_neili>=1200 / force>=100 / cuff>=100 / cuff>=mizong-houquan
  # （须空手检查 weapon/secondary_weapon 为空 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 55 / neili 78（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 55, neili: 78}

  # LPC `valid_learn(object me)`（源 mizong-houquan.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练迷踪猴拳必须空手。\n"}

      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为太弱，无法练迷踪猴拳。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候不够，无法练迷踪猴拳。\n"}

      Stats.skill(stats, "cuff") < 100 ->
        {:error, "你的基本拳法火候不够，无法练迷踪猴拳。\n"}

      Stats.skill(stats, "cuff") < lvl ->
        {:error, "你的基本拳法水平有限，无法领会更高深的迷踪猴拳。\n"}

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
    %{"zhou" => Kantele.Combat.Skills.Performs.MizongHouquan.Zhou}
  end
  def actions(), do: @actions

end

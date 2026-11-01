defmodule Kantele.Combat.Skills.LutouZhang do
  @moduledoc """
  鹿头杖法（对照 `kungfu/skill/lutou-zhang.c`）

  杖法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/lutou_zhang/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / force>=60 / staff>=20 / staff>=lutou-zhang）与
  练招消耗 `practice_cost`（LPC 扣 qi 75 / neili 78，须持杖）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持杖（weapon skill_type=="staff"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N右手托住杖端，一招「拦鹊式」，左掌居中一击，令其凭惯性倒向$n的肩头",
      "force" => 65,
      "attack" => 12,
      "dodge" => -10,
      "parry" => 5,
      "damage" => 35,
      "lvl" => 0
    },
    %{
      "action" => "$N双眼发红，将手中$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 89,
      "attack" => 20,
      "dodge" => -10,
      "parry" => 8,
      "damage" => 44,
      "lvl" => 30
    },
    %{
      "action" => "$N快步跨出，左手平托$w，右掌猛推杖端，顶向$n的胸口",
      "force" => 128,
      "attack" => 35,
      "dodge" => -5,
      "parry" => 10,
      "damage" => 52,
      "lvl" => 60
    },
    %{
      "action" => "$N大喝一声，手中$w如飞龙般自掌中跃出，直向$n的胸口穿入",
      "force" => 150,
      "attack" => 34,
      "dodge" => -5,
      "parry" => 12,
      "damage" => 66,
      "lvl" => 80
    },
    %{
      "action" => "$N横持$w，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 200,
      "attack" => 46,
      "dodge" => -15,
      "parry" => 18,
      "damage" => 70,
      "lvl" => 100
    },
    %{
      "action" => "横持$w，一招「苍龙摆尾」，杖端化出无数个圆圈，凝滞沉重，把$n缠在其中",
      "force" => 240,
      "attack" => 67,
      "dodge" => 5,
      "parry" => 22,
      "damage" => 78,
      "lvl" => 120
    },
    %{
      "action" => "$N全身滚倒，$w盘地横飞，突出一招「大蟒翻身」，杖影把$n裹了起来",
      "force" => 270,
      "attack" => 89,
      "dodge" => -5,
      "parry" => 28,
      "damage" => 100,
      "lvl" => 140
    },
    %{
      "action" => "$N单腿独立，$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 310,
      "attack" => 102,
      "dodge" => -5,
      "parry" => 35,
      "damage" => 120,
      "lvl" => 160
    }
  ]

  @impl true
  def id(), do: "lutou-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 75 / neili 78（须持杖，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 75, neili: 78}

  # LPC `valid_learn(object me)`（源 lutou-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "staff" ->
        {:error, "你使用的武器不对。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不足，无法学习鹿头杖法。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅，无法学习鹿头杖法。\n"}

      Stats.skill(stats, "staff") < 20 ->
        {:error, "你的基本杖法太浅，无法学习鹿头杖法。\n"}

      Stats.skill(stats, "staff") < lvl ->
        {:error, "你的基本杖法水平有限，无法领会更高深的鹿头杖法。\n"}

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
    %{"tong" => Kantele.Combat.Skills.Performs.LutouZhang.Tong}
  end
  def actions(), do: @actions

end

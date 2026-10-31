defmodule Kantele.Combat.Skills.RulaiZhang do
  @moduledoc """
  武学实装「rulai-zhang」（源 rulai-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/rulai_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一声大喝，左掌叠于右掌之上，劈向$n",
      "force" => 210,
      "attack" => 22,
      "parry" => 31,
      "dodge" => 30,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N面色凝重，双掌轻抖，飘忽不定地拍向$n",
      "force" => 270,
      "attack" => 38,
      "parry" => 33,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N气沉丹田，双掌幻化一片掌影，将$n笼罩于内。",
      "force" => 320,
      "attack" => 62,
      "parry" => 44,
      "dodge" => 43,
      "damage" => 35,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N跨前一步，右掌中攻直进，向$n的$l连击三掌",
      "force" => 370,
      "attack" => 75,
      "parry" => 68,
      "dodge" => 55,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N沉身顿气，贯出双掌，顿时只见一片掌影攻向$n",
      "force" => 420,
      "attack" => 82,
      "parry" => 80,
      "dodge" => 52,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双掌平挥，猛击向$n的$l，毫无半点花巧可言",
      "force" => 460,
      "attack" => 103,
      "parry" => 101,
      "dodge" => 65,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N体内真气迸发，双掌缤纷拍出，顿时一片掌影笼罩$n",
      "force" => 510,
      "attack" => 128,
      "parry" => 125,
      "dodge" => 63,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左掌虚晃，右掌携着千钧之力猛然向$n的头部击落",
      "force" => 530,
      "attack" => 125,
      "parry" => 152,
      "dodge" => 77,
      "damage" => 90,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身子蓦的横移，右手横扫$n的$l，左手攻向$n的胸口",
      "force" => 580,
      "attack" => 131,
      "parry" => 115,
      "dodge" => 80,
      "damage" => 100,
      "lvl" => 160,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N陡然一声暴喝，真气迸发，双掌同时击向$n的$l",
      "force" => 620,
      "attack" => 132,
      "parry" => 123,
      "dodge" => 81,
      "damage" => 130,
      "lvl" => 180,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "rulai-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 180, neili: 200}

  # LPC `valid_learn(object me)`（源 rulai-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练千手如来掌必须空手。\n"}

      Stats.con(stats) < 32 ->
        {:error, "你先天根骨不足，无法学习千手如来掌。\n"}

      Stats.dex(stats) < 30 ->
        {:error, "你先天身法不足，无法学习千手如来掌。\n"}

      Stats.skill(stats, "buddhism") < 300 ->
        {:error, "你的禅宗心法不够，无法练千手如来掌。\n"}

      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够，无法练千手如来掌。\n"}

      not is_nil(max_neili) and max_neili < 3500 ->
        {:error, "你的内力修为太浅，无法练千手如来掌。\n"}

      Stats.skill(stats, "strike") < 200 ->
        {:error, "你的基本掌法火候不够，无法练千手如来掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的千手如来掌。\n"}

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

  @impl true
  def perform_list() do
    %{
      "zong" => Kantele.Combat.Skills.Performs.RulaiZhang.Zong
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

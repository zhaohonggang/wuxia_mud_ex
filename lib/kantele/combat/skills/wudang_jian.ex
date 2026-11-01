defmodule Kantele.Combat.Skills.WudangJian do
  @moduledoc """
  武当剑法（对照 `kungfu/skill/wudang-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/wudang_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=20 / sword>=wudang-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 25 / neili 10，须持剑）已按 LPC 迁移（2026-10-30）。
  招式表（query_action）的静态招式未在本文件建模，沿用基类占位（TODO）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N身体左转，左手剑指，两腿屈膝，右前臂内旋，剑尖前端一寸处短促抖腕发\n力，一招「飞燕入林」，手中$w轻轻颤动，一剑自上而下扎向$n的$l",
      "force" => 120,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 0,
      "skill_name" => "飞燕入林"
    },
    %{
      "action" => "$N身形不动，右前臂外旋，剑刃上崩，立马左腿弓步，一招「青龙吐水」，手\n中$w向前下反刺，一剑指向$n的$l",
      "force" => 120,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 10,
      "skill_name" => "青龙吐水"
    },
    %{
      "action" => "$N左脚向前一步，蹬地跳起，身体腾空疾速左转，右手$w先向前刺，随转体变\n向，使出一式「凤凰挚窝」，剑光如匹练般泄向$n的$l",
      "force" => 140,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 20,
      "skill_name" => "凤凰挚窝"
    },
    %{
      "action" => "$N碎步急进，提剑沿剑身方向疾速上崩，一招「白蛇吐信」直取$n的$l",
      "force" => 150,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 30,
      "skill_name" => "白蛇吐信"
    },
    %{
      "action" => "$N平剑斜洗，臂圆剑直，双脚交替弧形迈进，右手$w使出一式「玉女穿梭」，\n剑锋往来运转如梭，连绵不绝刺向$n的$l",
      "force" => 130,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 40,
      "skill_name" => "玉女穿梭"
    },
    %{
      "action" => "$N屈腕抬臂，剑由前向后上方抽带，挺起中平剑奋勇向前，右手$w使出一式\n「仙人指路」刺向$n的$l",
      "force" => 120,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 50,
      "skill_name" => "仙人指路"
    },
    %{
      "action" => "$N左撤步，抱剑当胸，挥剑做圆环形，正反搅动，右手$w一式「怀中抱月」，\n剑意圆润，刺向$n的$l",
      "force" => 110,
      "dodge" => 15,
      "lvl" => 60,
      "skill_name" => "怀中抱月"
    },
    %{
      "action" => "$N侧身退步，左手剑指划转，腰部一扭，上体后仰，右手$w一记「反身朝阳」\n自下上撩指向$n的$l",
      "force" => 150,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 70,
      "skill_name" => "反身朝阳"
    }
  ]

  @impl true
  def id(), do: "wudang-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / force>=20 / sword>=wudang-jian
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的武当剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 25 / neili 10（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 25, neili: 10}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"sheng" => Kantele.Combat.Skills.Performs.WudangJian.Sheng}
  end
  def actions(), do: @actions

end

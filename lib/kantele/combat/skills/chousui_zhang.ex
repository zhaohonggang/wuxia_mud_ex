defmodule Kantele.Combat.Skills.ChousuiZhang do
  @moduledoc """
  抽髓掌（对照 kungfu/skill/chousui-zhang.c）

  招式表为纯数据（@actions，取 LPC action 表的 5 式静态招式）。源文件用了
  `"dmage"` 拼写（缺 damage），此处按原值写入 `"damage"`；第 6 式「极意」
  （lvl 200，动态力/攻/闪/架/伤）与 `valid_combine`（三阴蜈蚣爪）见 TODO(migrate)。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N脸上露出诡异的笑容，隐隐泛出绿色的双掌扫向$n的$l",
      "force" => 180,
      "attack" => 49,
      "dodge" => -30,
      "parry" => -37,
      "damage" => 32,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N突然身形旋转起来扑向$n，双掌飞舞着拍向$n的$l",
      "force" => 230,
      "attack" => 56,
      "dodge" => -22,
      "parry" => -34,
      "damage" => 47,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N将毒质运至右手，一招「腐尸毒」阴毒无比地抓向$n的$l",
      "force" => 260,
      "attack" => 61,
      "dodge" => -20,
      "parry" => 10,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一声怪叫，双掌挟着一股腥臭之气拍向$n的$l",
      "force" => 380,
      "attack" => 79,
      "dodge" => 17,
      "parry" => 36,
      "damage" => 65,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N咬破舌尖，口中喷血，聚集全身的力量击向$n",
      "force" => 420,
      "attack" => 81,
      "dodge" => 27,
      "parry" => 21,
      "damage" => 75,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "chousui-zhang"

  @impl true
  def valid_enable(usage), do: usage == "strike" or usage == "parry"

  # TODO(migrate): LPC valid_learn 还要求 max_neili >= 1000（本引擎取 vitals.max_neili）
  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "poison") < 50 ->
        {:error, "你的基本毒技不足，无法练抽髓掌。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法练抽髓掌。\n"}

      Stats.skill(stats, "strike") < 80 ->
        {:error, "你的掌法根基不足，无法练抽髓掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法水平有限，无法领会更高深的抽髓掌法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 55}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def perform_list() do
    %{"dan" => Kantele.Combat.Skills.Performs.ChousuiZhang.Dan}
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

defmodule Kantele.Combat.Skills.BanruoZhang do
  @moduledoc """
  般若掌（对照 `kungfu/skill/banruo-zhang.c`）

  掌法载体：`valid_enable("strike")` / `valid_enable("parry")`。

  招式表为纯数据（`@actions`，取 LPC `action` 表的 11 式静态招式），选招用
  `Kantele.Combat.Skill.pick_action/3`（LPC `NewRandom` 加权，`level > lvl`
  严格过滤）。

  绝招实现见 `lib/kantele/combat/skills/performs/banruo_zhang/`。

  **已迁移**：`valid_learn` 门槛（LPC 要求空手、force>=30、max_neili>=100、
  strike>=banruo-zhang）—— 已实现 `valid_learn(stats, character)`：force>=30 /
  max_neili>=100（取 character.meta.vitals.max_neili）/ strike>=self 三道门；
  空手检查因装备状态未接入 skill 回调暂略（与既有迁移一致）。`practice_skill`
  已实现 `practice_cost()` = `%{qi: 65, neili: 64}`（LPC 扣 qi65/neili64），
  qi/neili 下限由 PracticeCommand.check_vitals 统一把关。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N前腿踢出，后腿脚尖点地，一式「横空出世」，二掌直出，攻向$n的上中下三路",
      "force" => 120,
      "attack" => 17,
      "dodge" => 5,
      "parry" => 12,
      "damage" => 5,
      "lvl" => 0,
      "skill_name" => "横空出世",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌划一半圆，一式「长虹贯日」，右掌斜穿而出，疾拍$n的胸前大穴",
      "force" => 150,
      "attack" => 25,
      "dodge" => 5,
      "parry" => 18,
      "damage" => 10,
      "lvl" => 10,
      "skill_name" => "长虹贯日",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一式「云断秦岭」，右掌上引，左掌由后而上一个甩劈，斩向$n的$l",
      "force" => 170,
      "attack" => 32,
      "dodge" => 6,
      "parry" => 22,
      "damage" => 10,
      "lvl" => 20,
      "skill_name" => "云断秦岭",
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N左掌护胸，右拳凝劲后发，一式「铁索拦江」，缓缓推向$n的$l",
      "force" => 190,
      "attack" => 38,
      "dodge" => -5,
      "parry" => 32,
      "damage" => 10,
      "lvl" => 40,
      "skill_name" => "铁索拦江",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一式「狂风卷地」，全身飞速旋转，双掌一前一后，猛地拍向$n的胸口",
      "force" => 210,
      "attack" => 51,
      "dodge" => 10,
      "parry" => 27,
      "damage" => 15,
      "lvl" => 70,
      "skill_name" => "狂风卷地",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N合掌抱球，猛吸一口气，一式「怀中抱月」，双掌疾推向$n的肩头",
      "force" => 250,
      "attack" => 52,
      "dodge" => 5,
      "parry" => 38,
      "damage" => 15,
      "lvl" => 90,
      "skill_name" => "怀中抱月",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N向上高高跃起，一式「高山流水」，居高临下，掌力笼罩$n的全身",
      "force" => 280,
      "attack" => 62,
      "dodge" => 20,
      "parry" => 56,
      "damage" => 15,
      "lvl" => 110,
      "skill_name" => "高山流水",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一式「摘星换斗」，劲气弥漫，双掌如轮，一环环向$n的$l斫去",
      "force" => 300,
      "attack" => 67,
      "dodge" => 10,
      "parry" => 52,
      "damage" => 20,
      "lvl" => 130,
      "skill_name" => "摘星换斗",
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N两掌上下护胸，一式「翻江搅海」，骤然化为满天掌雨，攻向$n",
      "force" => 320,
      "attack" => 71,
      "dodge" => 30,
      "parry" => 65,
      "damage" => 20,
      "lvl" => 140,
      "skill_name" => "翻江搅海",
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一式「金刚伏魔」，双手合十，对着$n微微一揖，全身内劲如巨浪般汹涌而出",
      "force" => 350,
      "attack" => 78,
      "dodge" => 10,
      "parry" => 68,
      "damage" => 30,
      "lvl" => 150,
      "skill_name" => "金刚伏魔",
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "banruo-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["strike", "parry"]

  # LPC valid_learn：空手 + force>=30 + max_neili>=100 + strike>=banruo-zhang。
  # 空手检查：装备状态未接入 skill 回调（与既有迁移一致，待统一装备通道）。
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不够，无法练般若掌。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练般若掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法火候水平有限，无法领会更高深的般若功。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练习消耗：LPC practice_skill 扣 qi 65 / neili 64"
  @impl true
  def practice_cost(), do: %{qi: 65, neili: 64}

  @doc "按等级加权随机选一招（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  # 般若掌无动态招式表，query_action/3 与 /2 行为一致（忽略 attacker）
  @impl true
  def query_action(_level, rng, _attacker), do: query_action(_level, rng)

  @impl true
  def perform_list() do
    %{"feng" => Kantele.Combat.Skills.Performs.BanruoZhang.Feng}
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "当前等级对应的最高招式名（query_skill_name，LPC `level >= lvl`）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> action["skill_name"]
    end
  end
end

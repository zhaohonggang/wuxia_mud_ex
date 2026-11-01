defmodule Kantele.Combat.Skills.QianyeShou do
  @moduledoc """
  千叶手（对照 `kungfu/skill/qianye-shou.c`）

  手法载体：`valid_enable("hand")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qianye_shou/`。

  学习门槛 `valid_learn/2`（force>=40 / max_neili>=200 / hand>=self）与练招消耗
  `practice_cost`（qi 68 / neili 64）已按 LPC 迁移（2026-10-30）。LPC valid_learn 的「须空手」检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一式「南海礼佛」，右手虚晃，左手扬起，突然拍向$n的背后二穴",
      "force" => 90,
      "attack" => 15,
      "dodge" => 10,
      "parry" => 25,
      "lvl" => 0,
      "skill_name" => "南海礼佛"
    },
    %{
      "action" => "$N侧身一晃，一式「金玉瓦砾」，左手拿向$n的肩头，右拳打向$n的胸口",
      "force" => 110,
      "attack" => 18,
      "dodge" => 10,
      "parry" => 35,
      "lvl" => 30,
      "skill_name" => "金玉瓦砾"
    },
    %{
      "action" => "$N一式「人命呼吸」，右手环拢成爪，一出手就向扣$n的咽喉要害",
      "force" => 140,
      "attack" => 25,
      "dodge" => 20,
      "parry" => 50,
      "damage" => 5,
      "lvl" => 60,
      "skill_name" => "人命呼吸"
    },
    %{
      "action" => "$N左手虚招，右掌直立，一式「镜里观影」，错步飘出，疾拍$n的面门",
      "force" => 180,
      "attack" => 31,
      "dodge" => 20,
      "parry" => 60,
      "damage" => 10,
      "lvl" => 90,
      "skill_name" => "镜里观影"
    },
    %{
      "action" => "$N使一式「水中捉月」，左拳上格，右手探底突出，抓向$n的裆部",
      "force" => 240,
      "attack" => 42,
      "dodge" => 30,
      "parry" => 62,
      "damage" => 15,
      "lvl" => 110,
      "skill_name" => "水中捉月"
    },
    %{
      "action" => "$N双拳挥舞，一式「浮云去来」，两手环扣，拢成圈状，猛击$n的下颌",
      "force" => 310,
      "attack" => 55,
      "dodge" => 30,
      "parry" => 67,
      "damage" => 20,
      "lvl" => 130,
      "skill_name" => "浮云去来"
    },
    %{
      "action" => "$N一式「水泡出没」，十指伸缩，虚虚实实地袭向$n的全身要穴",
      "force" => 340,
      "attack" => 58,
      "dodge" => 35,
      "parry" => 71,
      "damage" => 25,
      "lvl" => 140,
      "skill_name" => "水泡出没"
    },
    %{
      "action" => "$N双手抱拳，一式「梦里明明」，掌影翻飞，同时向$n施出九九八十一招",
      "force" => 380,
      "attack" => 62,
      "dodge" => 41,
      "parry" => 72,
      "damage" => 30,
      "lvl" => 150,
      "skill_name" => "梦里明明"
    },
    %{
      "action" => "$N一式「觉后空空」，拳招若隐若现，若有若无，缓缓地拍向$n的丹田",
      "force" => 410,
      "attack" => 69,
      "dodge" => 40,
      "parry" => 78,
      "damage" => 35,
      "lvl" => 160,
      "skill_name" => "觉后空空"
    }
  ]

  @impl true
  def id(), do: "qianye-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 68 / neili 64（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 68, neili: 64}

  # LPC `valid_learn(object me)`（源 qianye-shou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练如来千叶手必须空手。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候不够，无法学如来千叶手。\n"}

      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力太弱，无法练如来千叶手。\n"}

      Stats.skill(stats, "hand") < lvl ->
        {:error, "你的基本手法水平有限，无法领会更高深的如来千叶手。\n"}

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
    %{"qianye" => Kantele.Combat.Skills.Performs.QianyeShou.Qianye}
  end
  def actions(), do: @actions

end

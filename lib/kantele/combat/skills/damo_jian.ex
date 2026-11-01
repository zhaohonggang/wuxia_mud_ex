defmodule Kantele.Combat.Skills.DamoJian do
  @moduledoc """
  达摩剑法（对照 `kungfu/skill/damo-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/damo_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=300 / int>=30 / force>=60 / sword>=damo-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 62 / neili 69，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N使一式「万事随缘往」，手中$w嗡嗡微振，幻成一条疾光刺向$n的$l",
      "force" => 90,
      "attack" => 30,
      "dodge" => 10,
      "parry" => 15,
      "damage" => 15,
      "lvl" => 0,
      "skill_name" => "万事随缘往"
    },
    %{
      "action" => "$N错步上前，使出「来去若梦行」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 140,
      "attack" => 50,
      "dodge" => 15,
      "parry" => 25,
      "damage" => 30,
      "lvl" => 40,
      "skill_name" => "来去若梦行"
    },
    %{
      "action" => "$N一式「浮世沧桑远」，纵身飘开数尺，运发剑气，手中$w遥摇指向$n的$l",
      "force" => 160,
      "attack" => 60,
      "dodge" => 25,
      "parry" => 28,
      "damage" => 40,
      "lvl" => 80,
      "skill_name" => "浮世沧桑远"
    },
    %{
      "action" => "$N纵身轻轻跃起，一式「轮回法舟轻」，剑光如轮疾转，霍霍斩向$n的$l",
      "force" => 180,
      "attack" => 70,
      "dodge" => 20,
      "parry" => 35,
      "damage" => 55,
      "lvl" => 120,
      "skill_name" => "轮回法舟轻"
    },
    %{
      "action" => "$N手中$w中宫直进，一式「水月通禅寂」，无声无息地对准$n的$l刺出一剑",
      "force" => 220,
      "attack" => 80,
      "dodge" => 25,
      "parry" => 42,
      "damage" => 60,
      "lvl" => 130,
      "skill_name" => "水月通禅寂"
    },
    %{
      "action" => "$N手中$w斜指苍天，剑芒吞吐，一式「鱼龙听梵音」，对准$n的$l斜斜击出",
      "force" => 260,
      "attack" => 85,
      "dodge" => 25,
      "parry" => 51,
      "damage" => 70,
      "lvl" => 140,
      "skill_name" => "鱼龙听梵音"
    },
    %{
      "action" => "$N左指凌空虚点，右手$w逼出丈许雪亮剑芒，一式「千里一苇去」刺向$n的$l",
      "force" => 320,
      "attack" => 90,
      "dodge" => 30,
      "parry" => 59,
      "damage" => 75,
      "lvl" => 150,
      "skill_name" => "千里一苇去"
    },
    %{
      "action" => "$N合掌跌坐，一式「禅心顿自明」，$w自怀中跃出，如疾电般射向$n的胸口",
      "force" => 380,
      "attack" => 95,
      "dodge" => 25,
      "parry" => 67,
      "damage" => 90,
      "lvl" => 160,
      "skill_name" => "禅心顿自明"
    }
  ]

  @impl true
  def id(), do: "damo-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=300 / int>=30 / force>=60 / sword>=damo-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力不够。\n"}

      Stats.int(stats) < 30 ->
        {:error, "你的先天悟性不足。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的达摩剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 62 / neili 69（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 62, neili: 69}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "luan" => Kantele.Combat.Skills.Performs.DamoJian.Luan,
      "qingxin" => Kantele.Combat.Skills.Performs.DamoJian.Qingxin,
      "sanjue" => Kantele.Combat.Skills.Performs.DamoJian.Sanjue,
      "shang" => Kantele.Combat.Skills.Performs.DamoJian.Shang,
      "zhe" => Kantele.Combat.Skills.Performs.DamoJian.Zhe
    }
  end
  def actions(), do: @actions

end

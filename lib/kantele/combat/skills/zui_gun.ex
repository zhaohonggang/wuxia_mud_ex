defmodule Kantele.Combat.Skills.ZuiGun do
  @moduledoc """
  武学实装「zui-gun」（源 zui-gun.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zui_gun/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "「蓝采和，提篮劝酒醉朦胧」，$N手中$w半提，缓缓划向$n的$l",
      "force" => 110,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 0,
      "damage" => 10,
      "lvl" => 10,
      "damage_type" => "挫伤",
      "skill_name" => "蓝采和，提篮劝酒醉朦胧"
    },
    %{
      "action" => "「何仙姑，拦腰敬酒醉仙步」，$N左掌护胸，右臂挟棍猛地扫向$n的腰间",
      "force" => 130,
      "attack" => 24,
      "parry" => 10,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 20,
      "damage_type" => "挫伤",
      "skill_name" => "何仙姑，拦腰敬酒醉仙步"
    },
    %{
      "action" => "「曹国舅，千杯不醉倒金盅」，$N倒竖$w，指天打地，向$n的$l劈去",
      "force" => 150,
      "attack" => 32,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "挫伤",
      "skill_name" => "曹国舅，千杯不醉倒金盅"
    },
    %{
      "action" => "「韩湘子，铁棍提胸醉拔萧」，$N横提$w，棍端划了个半圈，击向$n的$l",
      "force" => 180,
      "attack" => 41,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "韩湘子，铁棍提胸醉拔萧"
    },
    %{
      "action" => "「汉钟离，跌步翻身醉盘龙」，$N手中棍花团团，疾风般向卷向$n",
      "force" => 220,
      "attack" => 42,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "挫伤",
      "skill_name" => "汉钟离，跌步翻身醉盘龙"
    },
    %{
      "action" => "「铁拐李，踢倒金山醉玉池」，$N单腿支地，一腿一棍齐齐击向$n的$l",
      "force" => 260,
      "attack" => 47,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "铁拐李，踢倒金山醉玉池"
    },
    %{
      "action" => "「张果老，醉酒抛杯倒骑驴」，$N扭身反背，$w从胯底钻出，戳向$n的胸口",
      "force" => 290,
      "attack" => 52,
      "parry" => 20,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 100,
      "damage_type" => "挫伤",
      "skill_name" => "张果老，醉酒抛杯倒骑驴"
    },
    %{
      "action" => "「吕洞宾，酒醉提壶力千钧」，$N腾空而起，如山棍影，疾疾压向$n",
      "force" => 310,
      "attack" => 54,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "吕洞宾，酒醉提壶力千钧"
    }
  ]

  @impl true
  def id(), do: "zui-gun"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 58, neili: 54}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
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

end

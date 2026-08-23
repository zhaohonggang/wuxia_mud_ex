defmodule Kantele.Combat.Skills do
  @moduledoc """
  武学注册表：技能 id -> 实现 module
  """

  @skills %{
    "liuxin-jian" => Kantele.Combat.Skills.LiuxinJian,
    "liuxi-neigong" => Kantele.Combat.Skills.LiuxiNeigong
  }

  def all(), do: @skills

  def get(id) when is_binary(id), do: Map.get(@skills, id)
  def get(_id), do: nil

  def known?(id), do: Map.has_key?(@skills, id)

  @doc """
  按用法解析可 enable 的特技（对应 valid_enable）

  玩家 map_skill 之后，攻击/招架/内功都会映射到特技模块
  """
  def enabled_for(stats, usage) do
    case Kantele.Character.Stats.mapped(stats, usage) do
      nil -> nil
      skill_id -> get(skill_id)
    end
  end
end

defmodule Kantele.Combat.Skills.DefaultActions do
  @moduledoc """
  未启用特技时的通用招式（拳脚与基础兵刃）
  """

  @unarmed [
    %{
      "action" => "$N右拳一收一送，直捣$n的$l",
      "force" => 0,
      "attack" => 10,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "挥拳猛击"
    },
    %{
      "action" => "$N侧身进步，一记肘锤撞向$n的$l",
      "force" => 0,
      "attack" => 15,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 8,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "肘锤"
    },
    %{
      "action" => "$N双掌翻飞，连环拍向$n的$l",
      "force" => 0,
      "attack" => 20,
      "dodge" => 5,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "震伤",
      "skill_name" => "连环双掌"
    }
  ]

  @weaponed [
    %{
      "action" => "$N手中兵刃一振，斜劈向$n的$l",
      "force" => 0,
      "attack" => 12,
      "dodge" => 0,
      "parry" => 5,
      "damage" => 6,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "基础挥砍"
    },
    %{
      "action" => "$N手腕翻转，兵刃化作一道寒光罩向$n的$l",
      "force" => 0,
      "attack" => 18,
      "dodge" => 0,
      "parry" => 10,
      "damage" => 10,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "突刺"
    }
  ]

  def query_action(attack_skill, level, rng \\ &:rand.uniform/1)

  def query_action("unarmed", level, rng) do
    Kantele.Combat.Skill.pick_action(@unarmed, level, rng)
  end

  def query_action(_skill_type, level, rng) do
    Kantele.Combat.Skill.pick_action(@weaponed, level, rng)
  end
end

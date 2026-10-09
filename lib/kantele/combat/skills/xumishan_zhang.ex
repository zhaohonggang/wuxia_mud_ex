defmodule Kantele.Combat.Skills.XumishanZhang do
  @moduledoc """
  武学实装「xumishan-zhang」（源 xumishan-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xumishan_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N前腿踢出，后腿脚尖点地，一式「五丁开山」，双掌直击$n的面门",
      "force" => 150,
      "attack" => 15,
      "parry" => 20,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "五丁开山"
    },
    %{
      "action" => "$N左掌划一半圆，一式「壁立千刃」，右掌斜穿而出，疾拍$n的胸前大穴",
      "force" => 180,
      "attack" => 20,
      "parry" => 20,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "壁立千刃"
    },
    %{
      "action" => "$N使一式「云断秦岭」，右掌上引，左掌由后而上一个甩劈，斩向$n的$l",
      "force" => 200,
      "attack" => 30,
      "parry" => 10,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 50,
      "damage_type" => "劈伤",
      "skill_name" => "云断秦岭"
    },
    %{
      "action" => "$N左掌护胸，右掌凝劲后发，一式「日坠苍山」，缓缓推向$n的$l",
      "force" => 240,
      "attack" => 80,
      "parry" => 10,
      "dodge" => -5,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "日坠苍山"
    },
    %{
      "action" => "$N使一式「山高云淡」，身行一纵，双掌一前一后，猛地击向$n的头顶百汇大穴",
      "force" => 250,
      "attack" => 50,
      "parry" => 60,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "山高云淡"
    },
    %{
      "action" => "$N双掌合十，深吸一口气，一式「蒙蒙群山」，双掌骤然化出一片掌影，击向$n的前胸",
      "force" => 280,
      "attack" => 50,
      "parry" => 30,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 125,
      "damage_type" => "瘀伤",
      "skill_name" => "蒙蒙群山"
    },
    %{
      "action" => "$N向上高高跃起，一式「高山流水」，居高临下，掌力笼罩$n的全身",
      "force" => 300,
      "attack" => 60,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "高山流水"
    },
    %{
      "action" => "$N使一式「峰回路转」，劲气弥漫，双掌如轮，一掌强过一掌的向$n劈去",
      "force" => 350,
      "attack" => 70,
      "parry" => 55,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 175,
      "damage_type" => "劈伤",
      "skill_name" => "峰回路转"
    },
    %{
      "action" => "$N两掌上下护胸，一式「山穷水尽」，骤然化为满天掌雨，攻向$n",
      "force" => 400,
      "attack" => 80,
      "parry" => 60,
      "dodge" => 30,
      "damage" => 55,
      "lvl" => 200,
      "damage_type" => "瘀伤",
      "skill_name" => "山穷水尽"
    },
    %{
      "action" => "$N一式「排山倒海」，双掌一圈，全身内力如巨浪般汹涌而出，$n顿觉避无可避",
      "force" => 450,
      "attack" => 100,
      "parry" => 80,
      "dodge" => 50,
      "damage" => 60,
      "lvl" => 250,
      "damage_type" => "内伤",
      "skill_name" => "排山倒海"
    }
  ]

  @impl true
  def id(), do: "xumishan-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 75}

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

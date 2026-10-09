defmodule Kantele.Combat.Skills.QingmangZhang do
  @moduledoc """
  武学实装「qingmang-zhang」（源 qingmang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qingmang_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N前腿踢出，后腿脚尖点地，一式「横空出世」，二掌直出，攻向$n",
      "force" => 120,
      "attack" => 17,
      "parry" => 12,
      "dodge" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌划一半圆，一式「长虹贯日」，右掌斜穿而出，疾拍$n的胸前",
      "force" => 150,
      "attack" => 25,
      "parry" => 18,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 10,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一式「云断秦岭」，右掌上引，左掌由后而上一个甩劈，斩向$n",
      "force" => 170,
      "attack" => 32,
      "parry" => 22,
      "dodge" => 6,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "劈伤"
    },
    %{
      "action" => "$N左掌护胸，右拳凝劲后发，一式「铁索拦江」，缓缓推向$n的$l",
      "force" => 190,
      "attack" => 38,
      "parry" => 32,
      "dodge" => -5,
      "damage" => 10,
      "lvl" => 40,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一式「狂风卷地」，全身飞速旋转，双掌一前一后，猛地拍向$n",
      "force" => 210,
      "attack" => 51,
      "parry" => 27,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 70,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N合掌抱球，猛吸一口气，一式「怀中抱月」，双掌疾推向$n的肩头",
      "force" => 250,
      "attack" => 52,
      "parry" => 38,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N向上高高跃起，一式「高山流水」，居高临下，掌力笼罩$n的全身",
      "force" => 280,
      "attack" => 62,
      "parry" => 56,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 110,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "qingmang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 30}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

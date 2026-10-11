defmodule Kantele.Combat.Skills.MeinvQuan do
  @moduledoc """
  武学实装「meinv-quan」（源 meinv-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 13 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/meinv_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「红玉击鼓」 ，双臂交互快击",
      "force" => 40,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "红玉击鼓"
    },
    %{
      "action" => "$N突然变为「红拂夜奔」，出其不意的叩关直入，令$n大吃一惊",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 10,
      "damage_type" => "内伤",
      "skill_name" => "红拂夜奔"
    },
    %{
      "action" => "$N招式一变成「绿珠坠楼」，扑地攻敌下盘，委实难测",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 22,
      "damage_type" => "内伤",
      "skill_name" => "绿珠坠楼"
    },
    %{
      "action" => "$N双掌连拍数下，接著连绵不断拍出，原来是「文姬归汉」，共胡笳十八拍",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 18,
      "lvl" => 34,
      "damage_type" => "内伤",
      "skill_name" => "文姬归汉"
    },
    %{
      "action" => "$N使出「红线盗盒」，以空手入白刃之技向$n手中兵刃夺去",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 48,
      "damage_type" => "内伤",
      "skill_name" => "红线盗盒"
    },
    %{
      "action" => "$N一式「木兰弯弓」，左手如抱满月，右手疾挥而过，令$n目瞪口呆",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 22,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "木兰弯弓"
    },
    %{
      "action" => "$N忽然昂首如吟明月，双掌从不可思议的角度攻了过来，原来是一招「班姬赋诗」",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 24,
      "lvl" => 71,
      "damage_type" => "内伤",
      "skill_name" => "班姬赋诗"
    },
    %{
      "action" => "$N使招「蛮腰纤纤」，腰肢轻摆避开，紧跟着挥掌攻击$n的前胸",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 82,
      "damage_type" => "内伤",
      "skill_name" => "蛮腰纤纤"
    },
    %{
      "action" => "$N五指在自己头发上一梳，跟著软软的挥了出去，脸上微微一笑，却是一招「丽华梳装」。",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 95,
      "damage_type" => "内伤",
      "skill_name" => "丽华梳装"
    },
    %{
      "action" => "$N见$n呆住，伸指戳出，却是一招「萍姬针神」。",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 41,
      "lvl" => 109,
      "damage_type" => "内伤",
      "skill_name" => "萍姬针神"
    },
    %{
      "action" => "$N突然间蹙起眉头，宛如「西子捧心」，双掌自自己胸口攻出",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 42,
      "lvl" => 129,
      "damage_type" => "内伤",
      "skill_name" => "西子捧心"
    },
    %{
      "action" => "$N脚下翩若惊鸦、矫若游龙，犹如在水上漂行一般，却是一招「洛神微步」",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 50,
      "lvl" => 149,
      "damage_type" => "内伤",
      "skill_name" => "洛神微步"
    },
    %{
      "action" => "$N使招「曹令割鼻」，挥手在自己脸上斜削一掌，左掌削过，右掌又削，连绵不断",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 45,
      "lvl" => 179,
      "damage_type" => "内伤",
      "skill_name" => "曹令割鼻"
    }
  ]

  @impl true
  def id(), do: "meinv-quan"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 40}

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


  @impl true
  def perform_list() do
    %{
      "you" => Kantele.Combat.Skills.Performs.MeinvQuan.You
    }
  end
end

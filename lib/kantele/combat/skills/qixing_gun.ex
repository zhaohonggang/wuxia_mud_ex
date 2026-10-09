defmodule Kantele.Combat.Skills.QixingGun do
  @moduledoc """
  武学实装「qixing-gun」（源 qixing-gun.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qixing_gun/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N贴地斜飞，一招「雁行斜击」，尚未落地，$w已指向$n的后心",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N小步连跳，左手上举，右手$w使一式「浪迹天涯」直攻$n的左肋",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一招「花前月下」，模拟冰轮横空，清光铺地之光景，自上而下搏击",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 9,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N棍柄提起，棍尖下指，一招「清饮小酌」，犹如提壶斟酒扫$n的下盘",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 19,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N使出「抚琴按箫」，$w提至唇边，如同清音出箫，棍掌直出，划向$n的$l",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 60,
      "lvl" => 29,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N$w直截进击，自左而右，横扫数尺，一式「横行漠北」，迅疾逼向$n的肩头",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 70,
      "lvl" => 39,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一招「举案齐眉」，左手捏棍诀，跃步落地，右手$w斜刺$n的左腰",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 80,
      "lvl" => 59,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N左掌前挥，右手扬棍跟随，一招「推窗望月」，身形前扬，往$n的$l杀至",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 90,
      "lvl" => 79,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一招「分花拂柳」，$w似左实有右，似右实左，虚实莫辩，点向$n的腹部",
      "force" => 380,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 115,
      "lvl" => 99,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N一招「锦笔生花」，英姿勃发，$w舞出数点寒心，若梅桃盛开，点向$n的$l",
      "force" => 380,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 115,
      "lvl" => 99,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "qixing-gun"

  @impl true
  def valid_enable(usage), do: usage in ["club", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 70}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

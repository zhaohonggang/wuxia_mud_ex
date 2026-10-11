defmodule Kantele.Combat.Skills.ShenzhangBada do
  @moduledoc """
  武学实装「shenzhang-bada」（源 shenzhang-bada.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shenzhang_bada/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「横云断峰」左掌佯攻，右掌蓄势击向$n的$l",
      "force" => 120,
      "attack" => 40,
      "parry" => 20,
      "dodge" => -15,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "淤伤",
      "skill_name" => "横云断峰"
    },
    %{
      "action" => "$N飞身上前，双掌同时击出，一招「三羊开泰」，将$n笼罩于掌风之中",
      "force" => 150,
      "attack" => 50,
      "parry" => 15,
      "dodge" => 0,
      "damage" => 35,
      "lvl" => 20,
      "damage_type" => "淤伤",
      "skill_name" => "三羊开泰"
    },
    %{
      "action" => "$N一招「跨虎登山」，左掌长驱直进，迅雷般拍向$n的$l",
      "force" => 180,
      "attack" => 60,
      "parry" => 25,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 40,
      "damage_type" => "淤伤",
      "skill_name" => "跨虎登山"
    },
    %{
      "action" => "$N一招「龙跃深渊」，后退了一步，随后身形往后一个倒纵，右掌凌空拍向$n的$l",
      "force" => 200,
      "attack" => 70,
      "parry" => 35,
      "dodge" => -15,
      "damage" => 80,
      "lvl" => 60,
      "damage_type" => "淤伤",
      "skill_name" => "龙跃深渊"
    },
    %{
      "action" => "$N一招「雁落平沙」，身体半蹲，双掌一扫，两道劲风击向$n的下盘",
      "force" => 230,
      "attack" => 80,
      "parry" => 30,
      "dodge" => -15,
      "damage" => 110,
      "lvl" => 80,
      "damage_type" => "淤伤",
      "skill_name" => "雁落平沙"
    },
    %{
      "action" => "$N一个转身，一招「玄鸟划抄」，右掌连拍，掌风分三路击向$n",
      "force" => 270,
      "attack" => 100,
      "parry" => 30,
      "dodge" => 5,
      "damage" => 140,
      "lvl" => 120,
      "damage_type" => "淤伤",
      "skill_name" => "玄鸟划抄"
    },
    %{
      "action" => "$N纵身而上，一招「盘龙绕步」，左掌一圈，右掌随即直拍向$n的胸口",
      "force" => 300,
      "attack" => 100,
      "parry" => 10,
      "dodge" => -15,
      "damage" => 160,
      "lvl" => 160,
      "damage_type" => "淤伤",
      "skill_name" => "盘龙绕步"
    },
    %{
      "action" => "$N身体旋转起来，一招「威镇八方」，幻出无数掌影，同时击向$n",
      "force" => 350,
      "attack" => 120,
      "parry" => 50,
      "dodge" => 15,
      "damage" => 200,
      "lvl" => 200,
      "damage_type" => "淤伤",
      "skill_name" => "威镇八方"
    }
  ]

  @impl true
  def id(), do: "shenzhang-bada"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 90, neili: 70}

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
      "bafang" => Kantele.Combat.Skills.Performs.ShenzhangBada.Bafang
    }
  end
end

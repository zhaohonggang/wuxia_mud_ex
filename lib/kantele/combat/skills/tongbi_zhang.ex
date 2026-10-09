defmodule Kantele.Combat.Skills.TongbiZhang do
  @moduledoc """
  武学实装「tongbi-zhang」（源 tongbi-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tongbi_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「孤雁出群」，双掌合十，直直撞向$n的前胸",
      "force" => 120,
      "attack" => 25,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "孤雁出群"
    },
    %{
      "action" => "$N使出一招「 穿掌闪劈」，飞身跃起，双手猛拍，打向$n",
      "force" => 170,
      "attack" => 30,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 25,
      "damage_type" => "瘀伤",
      "skill_name" => "穿掌闪劈"
    },
    %{
      "action" => "只见$N使出一招「跨虎蹬山」，身形一展，运力于掌直取$n",
      "force" => 220,
      "attack" => 35,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "跨虎蹬山"
    },
    %{
      "action" => "$N使出一招「穿心透骨」，怒吼一声，一掌当头拍向$n的$l",
      "force" => 250,
      "attack" => 40,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "穿心透骨"
    },
    %{
      "action" => "$N使出一招「金阳破岭」，猛冲向前，掌如游龙般攻向$n",
      "force" => 280,
      "attack" => 45,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "金阳破岭"
    },
    %{
      "action" => "$N使出一招「六合劈」，伏身疾进，双掌自下扫向$n的$l",
      "force" => 320,
      "attack" => 50,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "六合劈"
    },
    %{
      "action" => "$N使出一招「齐天神威」，飞身横跃，双掌前后击出，拍向$n",
      "force" => 340,
      "attack" => 55,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "齐天神威"
    },
    %{
      "action" => "$N施展「大轮回」劲气弥漫，天空中出现无数掌影打向$n的$l",
      "force" => 360,
      "attack" => 65,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "大轮回"
    }
  ]

  @impl true
  def id(), do: "tongbi-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 30}

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

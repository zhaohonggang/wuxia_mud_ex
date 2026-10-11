defmodule Kantele.Combat.Skills.XuanmingZhang do
  @moduledoc """
  武学实装「xuanming-zhang」（源 xuanming-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuanming_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出一招「雪海茫茫」，双掌陡然攻出，带着丝丝阴风击向$n的$l",
      "force" => 100,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "雪海茫茫"
    },
    %{
      "action" => "$N使出一招「幽冥寒山」，左掌护胸，右掌掌心带着极寒之气拍向$n的$l",
      "force" => 130,
      "attack" => 30,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "幽冥寒山"
    },
    %{
      "action" => "$N怪叫一声，一招「阴风怒号」，双掌铺天盖地般拍向$n的$l",
      "force" => 160,
      "attack" => 45,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "阴风怒号"
    },
    %{
      "action" => "$N一照「凄雨冷风」，双掌拍出满天阴风，忽然右掌悄无声息的拍向$n的$l",
      "force" => 180,
      "attack" => 50,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "凄雨冷风"
    },
    %{
      "action" => "$N身形一跃，一招「亡命冰原」，左掌快若疾电般击向$n的$l",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "亡命冰原"
    },
    %{
      "action" => "$N阴笑一声，一招「孤山绝寒」，双掌一错，右掌忽然暴长数尺击向$n的$l",
      "force" => 280,
      "attack" => 95,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "孤山绝寒"
    },
    %{
      "action" => "$N一招「雪原孤月」，身形急晃，一跃而至$n跟前，右掌带着冲天寒气击向$n的$l",
      "force" => 320,
      "attack" => 110,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 70,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "雪原孤月"
    },
    %{
      "action" => "$N仰天长啸，一招「魂葬玄冥」，双掌掌风似千古不化的寒冰般扑向$n的$l",
      "force" => 360,
      "attack" => 135,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 95,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "魂葬玄冥"
    },
    %{
      "action" => "$N身法陡然一变，使出一式「幽玄冥冥」，掌影千变万幻，令$n无法躲闪",
      "force" => 420,
      "attack" => 150,
      "parry" => 75,
      "dodge" => 30,
      "damage" => 110,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "幽玄冥冥"
    },
    %{
      "action" => "$N仰天一声狂啸，一式「冰坚地狱」，双掌携带着万古冰坚直直贯向$n",
      "force" => 450,
      "attack" => 185,
      "parry" => 80,
      "dodge" => 40,
      "damage" => 160,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "冰坚地狱"
    }
  ]

  @impl true
  def id(), do: "xuanming-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 80}

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
      "lang" => Kantele.Combat.Skills.Performs.XuanmingZhang.Lang,
      "xing" => Kantele.Combat.Skills.Performs.XuanmingZhang.Xing,
      "ying" => Kantele.Combat.Skills.Performs.XuanmingZhang.Ying,
      "zhe" => Kantele.Combat.Skills.Performs.XuanmingZhang.Zhe
    }
  end
end

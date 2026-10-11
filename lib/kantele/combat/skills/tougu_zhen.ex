defmodule Kantele.Combat.Skills.TouguZhen do
  @moduledoc """
  武学实装「tougu-zhen」（源 tougu-zhen.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tougu_zhen/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N将内劲贯住指尖，携带着丝丝阴风一击凌空射向$n的$l",
      "force" => 140,
      "attack" => 25,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "丝丝阴风"
    },
    %{
      "action" => "$N表情麻木，陡的跃身而起，右手食指带着极寒之气直射$n的$l",
      "force" => 180,
      "attack" => 40,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "刺伤",
      "skill_name" => "极寒之气"
    },
    %{
      "action" => "$N怪叫一声，顿在半空翻个筋斗，将要落下之时，突然对准$n的$l处“飕”的一指射出",
      "force" => 220,
      "attack" => 50,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 38,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "一指射出"
    },
    %{
      "action" => "$N提气游走，不露身色绕至$n身后，猛的对准$n$l一指射出，$n刚要回挡，却发",
      "force" => 280,
      "attack" => 80,
      "parry" => 60,
      "dodge" => 80,
      "damage" => 55,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "乃是需招"
    },
    %{
      "action" => "$N向后疾退数尺，猛的又奔至$n跟前，左手食指快若疾电般点向$n的$l",
      "force" => 360,
      "attack" => 140,
      "parry" => 40,
      "dodge" => 45,
      "damage" => 80,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "亡命冰原"
    }
  ]

  @impl true
  def id(), do: "tougu-zhen"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

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
      "feng" => Kantele.Combat.Skills.Performs.TouguZhen.Feng
    }
  end
end

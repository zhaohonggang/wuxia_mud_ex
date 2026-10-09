defmodule Kantele.Combat.Skills.ShaolinTantui do
  @moduledoc """
  武学实装「shaolin-tantui」（源 shaolin-tantui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shaolin_tantui/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出「采刁踢」，左手以采刁手由上向前勾落，同时，左腿以勾腿式向$n$l勾踢而出",
      "force" => 50,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "采刁踢"
    },
    %{
      "action" => "$N将身体重心移至左脚，使右脚离地蓄劲，一招「套步踢」，右腿以勾腿式由上向前勾落",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "套步踢"
    },
    %{
      "action" => "$N右手化掌，向前直采而出，使出「翻身拦打」，右脚原地跺步，使身体转向$n踢出",
      "force" => 70,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "翻身拦打"
    },
    %{
      "action" => "$N收左手，右手原地向前架采而出，右脚顺势向$n$l直踢，正是一式「进步架打」",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "进步架打"
    },
    %{
      "action" => "$N将重心放至右脚，使左脚放虚，一招「回步冲捶」，向左原地转回，膝盖顺势抵向$n$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "回步冲捶"
    },
    %{
      "action" => "$N左掌向前直撑，封住底盘，一式「托按侧蹬」，右腿转身以反蹬腿向$n蹬出",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "托按侧蹬"
    },
    %{
      "action" => "$N一招「采刁撑腿」，左掌护住右腕不动，右手原地向外翻手抓采，接著左脚前踢$n",
      "force" => 140,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "采刁撑腿"
    },
    %{
      "action" => "$N左掌原地回圈，向前封出，一招「扭步挟肘」，右脚猛然拖进，向$n下盘猛踢三脚",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "扭步挟肘"
    },
    %{
      "action" => "$N双手化十字手，交叉於胸前，使出「并步迎抄」，双腿一跃，并踢$n$l",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "并步迎抄"
    },
    %{
      "action" => "$N跟着又是一招「并步迎抄」，十字手顺势向上双抄後，双腿凌空再次踢向$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "并步迎抄"
    }
  ]

  @impl true
  def id(), do: "shaolin-tantui"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 50}

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

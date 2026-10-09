defmodule Kantele.Combat.Skills.SongshanSword do
  @moduledoc """
  武学实装「songshan-sword」（源 songshan-sword.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/songshan_sword/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手$w一立，举剑过顶，弯腰躬身，使一招‘万岳朝宗’正是",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "万岳朝宗"
    },
    %{
      "action" => "$N手中$w突然间剑光一吐，化作一道白虹，端严雄伟，端丽飘逸，",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "千古人龙"
    },
    %{
      "action" => "$N手中$w突然间剑光一吐，一招‘叠翠浮青’化成一道青光，气",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "叠翠浮青"
    },
    %{
      "action" => "$N手中$w剑光一吐，一招‘玉进天池’威仪整肃，端严雄伟，向",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "玉进天池"
    },
    %{
      "action" => "$N左手向外一分，右手$w向右掠出，使的是嵩山派剑法‘开门见",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "开门见山"
    },
    %{
      "action" => "$N手中$w自上而下的向$n直劈下去，一招‘独劈华山’，真有石",
      "force" => 230,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "独劈华山"
    },
    %{
      "action" => "$N手中$w刷的一剑自左而右急削过去，正是一招嵩山派正",
      "force" => 290,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 65,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "天外玉龙"
    }
  ]

  @impl true
  def id(), do: "songshan-sword"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 26}

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

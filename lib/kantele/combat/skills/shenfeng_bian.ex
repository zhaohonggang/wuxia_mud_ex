defmodule Kantele.Combat.Skills.ShenfengBian do
  @moduledoc """
  武学实装「shenfeng-bian」（源 shenfeng-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shenfeng_bian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手合什，内力灌注, 一式「未牧」，腰间$w似有灵性，笔直的刺向$n的$l",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "未牧"
    },
    %{
      "action" => "$N沉肩滑步，手中$w一抖，一式「初调」，迅捷无比地分打左右两侧，$n顿时左右支绌，慌了手脚",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "初调"
    },
    %{
      "action" => "$N将内力注入$w，蓦地使出一式「受制」，$w矫夭飞舞，直如神龙破空一般抽向$n",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "受制"
    },
    %{
      "action" => "$N一声清啸，手中$w一招「回首」，划出漫天鞭影铺天盖地地向$n卷来，势道猛烈之极",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "回首"
    },
    %{
      "action" => "$N急速旋绕手中$w，一式「驯服」，挥出无数旋转气流向$n逼去 ",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "驯服"
    },
    %{
      "action" => "$N身体凌空飞起，右手大力挥出$w，一式「无碍」，一股排山倒海的鞭风直击向$n",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "无碍"
    },
    %{
      "action" => "$N面露微笑跨前一步，右手$w轻扬，使出一式「任运」，鞭势平和中正，不带丝毫霸气",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "任运"
    },
    %{
      "action" => "$N向前急进，双手握住$w，缓缓使出一式「相望」，鞭势沉稳, 一股劲风破空而起",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "相望"
    },
    %{
      "action" => "$N狂舞手中$w，一式「独照」，鞭若蛟龙, 盘旋飞舞",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "独照"
    },
    %{
      "action" => "$N身体螺旋飞舞，手中$w突然挥出，使出一式「双泯」，鞭势犹如雨中闪电,气势惊人",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "拉伤",
      "skill_name" => "双泯"
    }
  ]

  @impl true
  def id(), do: "shenfeng-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 20}

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

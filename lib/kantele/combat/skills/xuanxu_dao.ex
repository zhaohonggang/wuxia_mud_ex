defmodule Kantele.Combat.Skills.XuanxuDao do
  @moduledoc """
  武学实装「xuanxu-dao」（源 xuanxu-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuanxu_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「黄云万里动风色，白波九道流雪山」，脚踏「巽」位，手中$w劈出九道光影扑向\\n",
      "force" => 30,
      "attack" => 25,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一式「银河倒挂三石梁，香炉瀑布遥相望」，抢占「坎」位，手中$w化做片片刀光, 似\\n",
      "force" => 33,
      "attack" => 32,
      "parry" => 38,
      "dodge" => 26,
      "damage" => 18,
      "lvl" => 20,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一式「登高壮观天地间，大江茫茫去不黄」，闪向「震」位，手中$w化为漫天刀影，夹\\n",
      "force" => 40,
      "attack" => 38,
      "parry" => 43,
      "dodge" => 32,
      "damage" => 22,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一式「山川萧条极边土，胡骑凭陵杂风雨」，神情寂寥寡欢，在「艮」位突发一刀，以力压\\n",
      "force" => 60,
      "attack" => 42,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 26,
      "lvl" => 60,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一式「轮台九月风夜吼，一川碎石大如斗」，身体急速旋转，在「离」位如一团旋风，手中\\n",
      "force" => 80,
      "attack" => 45,
      "parry" => 55,
      "dodge" => 50,
      "damage" => 32,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N一式「杀气三时作阵云，寒声一夜传刁斗」，占住「兑」位，手中$w带着满天杀气劈向\\n",
      "force" => 90,
      "attack" => 52,
      "parry" => 55,
      "dodge" => 65,
      "damage" => 40,
      "lvl" => 100,
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "xuanxu-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 43}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

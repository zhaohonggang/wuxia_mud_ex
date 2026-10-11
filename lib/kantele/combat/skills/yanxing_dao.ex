defmodule Kantele.Combat.Skills.YanxingDao do
  @moduledoc """
  武学实装「yanxing-dao」（源 yanxing-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yanxing_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使出「让字诀」，上身侧过，手中$w斜斜砍出，一道白光劈向$n",
      "force" => 60,
      "attack" => 10,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "让字诀"
    },
    %{
      "action" => "$N使出「打字诀」，左手护顶，右手$w化作一道白芒直向$n的$l砍落",
      "force" => 80,
      "attack" => 15,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 21,
      "lvl" => 10,
      "damage_type" => "割伤",
      "skill_name" => "打字诀"
    },
    %{
      "action" => "$N使出「顶字诀」，$w斜上招架，顺势下剁，刀光不停指向$n的$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "顶字诀"
    },
    %{
      "action" => "$N使出「引字诀」，侧身而上，身形突闪，$w猛地弹出，把$n绞在刀光中",
      "force" => 120,
      "attack" => 25,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 32,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "引字诀"
    },
    %{
      "action" => "$N使出「套字诀」，左手急速缠住$n左手，手中$w一阵乱披风，刀光罩住$n",
      "force" => 140,
      "attack" => 25,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 37,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "套字诀"
    },
    %{
      "action" => "$N使出「陈字诀」，身法变得轻灵飘忽，捉摸不透，手中$w光反卷向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 43,
      "lvl" => 50,
      "damage_type" => "割伤",
      "skill_name" => "陈字诀"
    },
    %{
      "action" => "$N使出「探字诀」，轻盈地一个急转身，右手$w尽力向前，直抵$n的$l",
      "force" => 180,
      "attack" => 25,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 57,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "探字诀"
    },
    %{
      "action" => "$N凝神使出「逼字诀」，身随意转，手随心动，雪亮的刀光绕着$n疾速转动",
      "force" => 200,
      "attack" => 28,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 60,
      "lvl" => 70,
      "damage_type" => "割伤",
      "skill_name" => "逼字诀"
    },
    %{
      "action" => "$N凝神使出「藏字诀」，侧身藏刀，刀光陡现，势如千军万马，向$n奔腾而出",
      "force" => 230,
      "attack" => 33,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 62,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "藏字诀"
    },
    %{
      "action" => "$N凝神使出「错字诀」，双手交叉，只见$w刀光批攉，$n顿觉一阵寒气直逼过来",
      "force" => 250,
      "attack" => 38,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 70,
      "lvl" => 90,
      "damage_type" => "割伤",
      "skill_name" => "错字诀"
    }
  ]

  @impl true
  def id(), do: "yanxing-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 53, neili: 51}

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
      "huan" => Kantele.Combat.Skills.Performs.YanxingDao.Huan
    }
  end
end

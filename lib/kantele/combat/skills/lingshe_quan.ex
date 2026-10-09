defmodule Kantele.Combat.Skills.LingsheQuan do
  @moduledoc """
  武学实装「lingshe-quan」（源 lingshe-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lingshe_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「灵蛇出洞」，右手虚晃，左手扬起，突然拍向$n的背后二穴",
      "force" => 60,
      "attack" => 40,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "灵蛇出洞"
    },
    %{
      "action" => "$N侧身一晃，一式「虎头蛇尾」，左手拿向$n的肩头，右拳打向$n的胸口",
      "force" => 100,
      "attack" => 45,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "虎头蛇尾"
    },
    %{
      "action" => "$N一式「画蛇添足」，右手环拢成爪，一出手就向扣$n的咽喉要害",
      "force" => 130,
      "attack" => 50,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 5,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "画蛇添足"
    },
    %{
      "action" => "$N左手虚招，右掌直立，一式「杯弓蛇影」，错步飘出，疾拍$n的面门",
      "force" => 160,
      "attack" => 55,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 10,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "杯弓蛇影"
    },
    %{
      "action" => "$N使一式「蛇行鼠窜」，左拳上格，右手探底突出，抓向$n的裆部",
      "force" => 210,
      "attack" => 60,
      "parry" => 0,
      "dodge" => 65,
      "damage" => 15,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "蛇行鼠窜"
    },
    %{
      "action" => "$N一式「蛇磐青竹」，十指伸缩，虚虚实实地袭向$n的全身要穴",
      "force" => 250,
      "attack" => 70,
      "parry" => 0,
      "dodge" => 75,
      "damage" => 25,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "蛇磐青竹"
    },
    %{
      "action" => "$N双手抱拳，一式「万蛇汹涌」，掌影翻飞，同时向$n施出九九八十一招",
      "force" => 280,
      "attack" => 80,
      "parry" => 0,
      "dodge" => 75,
      "damage" => 30,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "万蛇汹涌"
    },
    %{
      "action" => "$N一式「白蛇吐信」，拳招若隐若现，若有若无，急急地拍向$n的丹田",
      "force" => 300,
      "attack" => 90,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 40,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "白蛇吐信"
    }
  ]

  @impl true
  def id(), do: "lingshe-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 55}

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

defmodule Kantele.Combat.Skills.LuoyingShenzhang do
  @moduledoc """
  武学实装「luoying-shenzhang」（源 luoying-shenzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/luoying_shenzhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手平伸，向外掠出，一式「春云乍展」，指尖轻轻反点$n的$l",
      "force" => 68,
      "attack" => 12,
      "parry" => 5,
      "dodge" => 4,
      "damage" => 2,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "春云乍展"
    },
    %{
      "action" => "$N右手五指缓缓一收，一式「回风拂柳」，五指忽然拂向$n五处大穴",
      "force" => 80,
      "attack" => 14,
      "parry" => 8,
      "dodge" => 7,
      "damage" => 5,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "回风拂柳"
    },
    %{
      "action" => "$N陡然一个轻巧转身，单掌劈落，一式「江城飞花」，拍向$n的头顶",
      "force" => 91,
      "attack" => 17,
      "parry" => 13,
      "dodge" => 10,
      "damage" => 9,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "江城飞花"
    },
    %{
      "action" => "$N突然跃起，双手连环，运掌如剑，一式「雨急风狂」，攻向$n的全身",
      "force" => 108,
      "attack" => 22,
      "parry" => 15,
      "dodge" => 17,
      "damage" => 12,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "雨急风狂"
    },
    %{
      "action" => "$N伸出右手并拢食指中指，捻个剑决，一式「星河在天」，直指$n中盘",
      "force" => 138,
      "attack" => 29,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 23,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "星河在天"
    },
    %{
      "action" => "$N突然抽身而退，一式「流华纷飞」，平身飞起，双掌向$n连拍数掌",
      "force" => 180,
      "attack" => 33,
      "parry" => 16,
      "dodge" => 13,
      "damage" => 28,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "流华纷飞"
    },
    %{
      "action" => "$N突然抽身跃起，右掌翻滚，一式「彩云追月」抢在左掌前向$n的$l拍去",
      "force" => 210,
      "attack" => 38,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 33,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "彩云追月"
    },
    %{
      "action" => "$N使一式「天如穹庐」，全身飞速旋转，双掌忽前忽后猛地拍向$n的胸口",
      "force" => 260,
      "attack" => 44,
      "parry" => 26,
      "dodge" => 34,
      "damage" => 41,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "天如穹庐"
    },
    %{
      "action" => "$N前后一揉，一式「朝云横度」，化掌如剑，一股凌厉剑气袭向$n下盘",
      "force" => 290,
      "attack" => 52,
      "parry" => 45,
      "dodge" => 43,
      "damage" => 51,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "朝云横度"
    },
    %{
      "action" => "$N使一式「白虹经天」，双掌舞出无数圈劲气，一环环向$n的$l斫去",
      "force" => 310,
      "attack" => 72,
      "parry" => 55,
      "dodge" => 41,
      "damage" => 68,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "白虹经天"
    },
    %{
      "action" => "$N双手食指和中指一和，一式「紫气东来」，一股强烈的气流涌向$n全身",
      "force" => 330,
      "attack" => 79,
      "parry" => 61,
      "dodge" => 36,
      "damage" => 85,
      "lvl" => 200,
      "damage_type" => "内伤",
      "skill_name" => "紫气东来"
    },
    %{
      "action" => "$N一式「落英漫天」，双掌在身前疾转，掌花飞舞，铺天盖地直指向$n",
      "force" => 378,
      "attack" => 84,
      "parry" => 65,
      "dodge" => 41,
      "damage" => 103,
      "lvl" => 220,
      "damage_type" => "瘀伤",
      "skill_name" => "落英漫天"
    }
  ]

  @impl true
  def id(), do: "luoying-shenzhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 40}

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

defmodule Kantele.Combat.Skills.HaotianZhang do
  @moduledoc """
  武学实装「haotian-zhang」（源 haotian-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 21 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/haotian_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一招「春江潮水」，双手划了个半圈，按向$n的$l",
      "force" => 60,
      "attack" => 30,
      "parry" => 31,
      "dodge" => 20,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "春江潮水"
    },
    %{
      "action" => "$N使一招「海上明月」，左手轻轻一挥，劈向$n的$l",
      "force" => 65,
      "attack" => 35,
      "parry" => 33,
      "dodge" => 38,
      "damage" => 10,
      "lvl" => 5,
      "damage_type" => "内伤",
      "skill_name" => "海上明月"
    },
    %{
      "action" => "$N右手掌心向外，由右向左，使一招「滟滟随波」，向$n的$l打去",
      "force" => 70,
      "attack" => 38,
      "parry" => 35,
      "dodge" => 36,
      "damage" => 15,
      "lvl" => 10,
      "damage_type" => "内伤",
      "skill_name" => "滟滟随波"
    },
    %{
      "action" => "$N使一招「江流宛转」，分击$n的胸口和$l",
      "force" => 76,
      "attack" => 42,
      "parry" => 36,
      "dodge" => 44,
      "damage" => 20,
      "lvl" => 15,
      "damage_type" => "内伤",
      "skill_name" => "江流宛转"
    },
    %{
      "action" => "$N使一招「月照花林」，左右掌同时击出，空中突然左右掌方向互变",
      "force" => 85,
      "attack" => 45,
      "parry" => 41,
      "dodge" => 42,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "月照花林"
    },
    %{
      "action" => "$N左手不住晃动，右掌一招「空中流霜」，向$n的$l打去",
      "force" => 96,
      "attack" => 49,
      "parry" => 42,
      "dodge" => 50,
      "damage" => 20,
      "lvl" => 25,
      "damage_type" => "内伤",
      "skill_name" => "空中流霜"
    },
    %{
      "action" => "$N左手变掌为啄，右掌立掌如刀，一招「汀上白沙」，劈向$n的$l",
      "force" => 98,
      "attack" => 55,
      "parry" => 44,
      "dodge" => 58,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "汀上白沙"
    },
    %{
      "action" => "$N左脚退后半步，右掌使一招「江天一色」，横挥向$n",
      "force" => 105,
      "attack" => 59,
      "parry" => 48,
      "dodge" => 63,
      "damage" => 14,
      "lvl" => 35,
      "damage_type" => "内伤",
      "skill_name" => "江天一色"
    },
    %{
      "action" => "$N一招「皎皎孤月」，左掌先发而后至，右掌后发而先至",
      "force" => 110,
      "attack" => 62,
      "parry" => 49,
      "dodge" => 54,
      "damage" => 14,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "皎皎孤月"
    },
    %{
      "action" => "$N双掌缩入袖中，双袖飞起扫向$n的$l，却是一招「长江流水」",
      "force" => 120,
      "attack" => 66,
      "parry" => 52,
      "dodge" => 62,
      "damage" => 12,
      "lvl" => 45,
      "damage_type" => "内伤",
      "skill_name" => "长江流水"
    },
    %{
      "action" => "$N左手虚按，右手划道弧线使一招「白云悠悠」，向$n的$l插去",
      "force" => 130,
      "attack" => 75,
      "parry" => 54,
      "dodge" => 60,
      "damage" => 16,
      "lvl" => 50,
      "damage_type" => "内伤",
      "skill_name" => "白云悠悠"
    },
    %{
      "action" => "$N双手变掌做拳，向前向后划弧，一招「青枫浦上」击向$n的$l",
      "force" => 150,
      "attack" => 81,
      "parry" => 55,
      "dodge" => 68,
      "damage" => 12,
      "lvl" => 55,
      "damage_type" => "内伤",
      "skill_name" => "青枫浦上"
    },
    %{
      "action" => "$N左手虚划，右手变掌为钩一记「楼月蜚回」击向$n的$l",
      "force" => 170,
      "attack" => 85,
      "parry" => 58,
      "dodge" => 76,
      "damage" => 28,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "楼月蜚回"
    },
    %{
      "action" => "$N施出「玉户帘中」，右掌向外挥出，左掌同时攻向$n",
      "force" => 200,
      "attack" => 88,
      "parry" => 61,
      "dodge" => 54,
      "damage" => 24,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "玉户帘中"
    },
    %{
      "action" => "$N由臂带手，在面前缓缓划过，使一招「鸿雁长飞」，挥向$n的$l",
      "force" => 220,
      "attack" => 92,
      "parry" => 62,
      "dodge" => 72,
      "damage" => 15,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "鸿雁长飞"
    },
    %{
      "action" => "$N负身就地，右掌使一招「鱼龙潜跃」，自下而上向$n的$l击去",
      "force" => 250,
      "attack" => 94,
      "parry" => 64,
      "dodge" => 67,
      "damage" => 18,
      "lvl" => 110,
      "damage_type" => "内伤",
      "skill_name" => "鱼龙潜跃"
    },
    %{
      "action" => "$N右手由钩变掌，双手掌心向上，右掌向前推出一招「月华流照」",
      "force" => 280,
      "attack" => 96,
      "parry" => 66,
      "dodge" => 81,
      "damage" => 28,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "月华流照"
    },
    %{
      "action" => "$N右掌不住向外扫出，是一式「闲潭落花」，左掌旋转着向$n攻去",
      "force" => 310,
      "attack" => 99,
      "parry" => 69,
      "dodge" => 66,
      "damage" => 21,
      "lvl" => 130,
      "damage_type" => "内伤",
      "skill_name" => "闲潭落花"
    },
    %{
      "action" => "$N右手经腹前经左肋向前撇出，使一招「江水流春」，向$n的$l锤去",
      "force" => 330,
      "attack" => 100,
      "parry" => 74,
      "dodge" => 64,
      "damage" => 32,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "江水流春"
    },
    %{
      "action" => "$N使一招「斜月沉沉」，左掌连划三个大圈，右掌从圈中穿出击向$n",
      "force" => 370,
      "attack" => 102,
      "parry" => 73,
      "dodge" => 72,
      "damage" => 35,
      "lvl" => 150,
      "damage_type" => "内伤",
      "skill_name" => "斜月沉沉"
    },
    %{
      "action" => "$N左手向上划弧拦出，右手使出「碣石潇湘」，不离$n头顶方寸之间",
      "force" => 400,
      "attack" => 105,
      "parry" => 79,
      "dodge" => 65,
      "damage" => 50,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "碣石潇湘"
    }
  ]

  @impl true
  def id(), do: "haotian-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 68, neili: 66}

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

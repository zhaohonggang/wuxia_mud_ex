defmodule Kantele.Combat.Skills.LanhuaShou do
  @moduledoc """
  武学实装「lanhua-shou」（源 lanhua-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lanhua_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手五指分开，微微一拂，一式「花疏云淡」拂向$n的膻中要穴",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "花疏云淡"
    },
    %{
      "action" => "$N侧身掠向$n，一式「轻云蔽月」，左手五指拨向$n的胸前大穴",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "轻云蔽月"
    },
    %{
      "action" => "$N使一式「云破月来」，左掌虚攻，并指斜前翻出，拍向$n的肩井穴",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "云破月来"
    },
    %{
      "action" => "$N微微侧身，右掌勾上，一式「幽兰弄影」，缓缓拂向$n的天突穴",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 45,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "幽兰弄影"
    },
    %{
      "action" => "$N使一式「芳兰竟体」，身影不定地掠至$n身后，猛地拍向$n的大椎穴",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "芳兰竟体"
    },
    %{
      "action" => "$N施出「兰桂齐芳」，双手向外一拨，逼向$n的华盖、璇玑、紫宫几处大穴",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 55,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "兰桂齐芳"
    },
    %{
      "action" => "$N一式「月影花香」，居高临下，拂出一道劲力罩向$n的百会大穴",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 40,
      "damage" => 65,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "月影花香"
    },
    %{
      "action" => "$N施展出「花好月圆」，双手疾拂，一环环的劲气逼向$n的上中下各大要穴",
      "force" => 320,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 45,
      "damage" => 70,
      "lvl" => 160,
      "damage_type" => "内伤",
      "skill_name" => "花好月圆"
    }
  ]

  @impl true
  def id(), do: "lanhua-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 53}

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
      "fei" => Kantele.Combat.Skills.Performs.LanhuaShou.Fei,
      "fu" => Kantele.Combat.Skills.Performs.LanhuaShou.Fu
    }
  end
end

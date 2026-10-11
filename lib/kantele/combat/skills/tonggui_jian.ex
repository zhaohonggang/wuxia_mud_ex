defmodule Kantele.Combat.Skills.TongguiJian do
  @moduledoc """
  武学实装「tonggui-jian」（源 tonggui-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tonggui_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N纵步上前，手中$w斜斜刺出，竟似不要命一般，疾斩$n而去",
      "force" => 290,
      "attack" => 171,
      "parry" => -240,
      "dodge" => -231,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w猛的反身递出，疾刺$n的$l，所施全为拼命的招数",
      "force" => 340,
      "attack" => 152,
      "parry" => -241,
      "dodge" => -192,
      "damage" => 232,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N面不露色，身形陡然加快，手中$w一剑快过一剑，尽数向$n刺去",
      "force" => 320,
      "attack" => 158,
      "parry" => -245,
      "dodge" => -183,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w光芒闪烁，在许许剑芒中递出杀着，完全出自$n意料之外",
      "force" => 390,
      "attack" => 168,
      "parry" => -193,
      "dodge" => -175,
      "damage" => 230,
      "lvl" => 0,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "tonggui-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "fen" => Kantele.Combat.Skills.Performs.TongguiJian.Fen
    }
  end
end

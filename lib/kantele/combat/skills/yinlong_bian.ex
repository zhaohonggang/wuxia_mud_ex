defmodule Kantele.Combat.Skills.YinlongBian do
  @moduledoc """
  武学实装「yinlong-bian」（源 yinlong-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yinlong_bian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N端坐不动，一式「神蛟初现」，手腕力抬，$w滚动飞舞，宛如灵蛇乱颤扫向$n",
      "force" => 98,
      "attack" => 41,
      "parry" => 15,
      "dodge" => -5,
      "damage" => 32,
      "lvl" => 0,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N一式「神蛟再现」，$w抖得笔直，“呲呲”破空声中向$n疾刺而去",
      "force" => 187,
      "attack" => 48,
      "parry" => 36,
      "dodge" => -20,
      "damage" => 47,
      "lvl" => 80,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N内劲到处，将$w抖动转成两个圆圈，一式「神蛟又现」，从半空中往$n缠下",
      "force" => 231,
      "attack" => 65,
      "parry" => 55,
      "dodge" => -10,
      "damage" => 93,
      "lvl" => 100,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N劲走螺旋，一式「吞天裂地势」，$w在$n眼前连变数种招式，忽然从$l处倒卷上来",
      "force" => 263,
      "attack" => 70,
      "parry" => 60,
      "dodge" => 5,
      "damage" => 102,
      "lvl" => 120,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N一声高喝，使出「真天罗势」，$w急速转动，鞭影纵横，似真似幻，绞向$n",
      "force" => 301,
      "attack" => 77,
      "parry" => 65,
      "dodge" => 6,
      "damage" => 121,
      "lvl" => 140,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N含胸拔背，一式「六道轮回势」，力道灵动威猛，劲力从四面八方向$n挤压出去",
      "force" => 331,
      "attack" => 85,
      "parry" => 70,
      "dodge" => 12,
      "damage" => 142,
      "lvl" => 160,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N力贯鞭梢，一招「大吉祥势」，手中$w舞出满天鞭影，排山倒海般扫向$n",
      "force" => 373,
      "attack" => 91,
      "parry" => 75,
      "dodge" => 17,
      "damage" => 163,
      "lvl" => 180,
      "damage_type" => "抽伤"
    },
    %{
      "action" => "$N力贯鞭梢，一招「龙飞十二重天势」，手中$w舞出满天鞭影，排山倒海般扫向$n",
      "force" => 401,
      "attack" => 98,
      "parry" => 85,
      "dodge" => 20,
      "damage" => 189,
      "lvl" => 200,
      "damage_type" => "抽伤"
    }
  ]

  @impl true
  def id(), do: "yinlong-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 120}

  # LPC `valid_learn(object me)`（源 yinlong-bian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (not (Skill.wielding?(character))) or (Skill.wielded_skill_type(character) != "whip") ->
        {:error, "你必须先找一条鞭子才能练银龙鞭法。\n"}

      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力不足，没有办法练银龙鞭法。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候太浅，没有办法练银龙鞭法。\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "你的基本鞭法火候太浅，没有办法练银龙鞭法。\n"}

      Stats.skill(stats, "whip") < lvl ->
        {:error, "你的基本鞭法水平还不够，无法领会更高深的银龙鞭法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "zhu" => Kantele.Combat.Skills.Performs.YinlongBian.Zhu
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

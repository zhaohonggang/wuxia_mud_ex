defmodule Kantele.Combat.Skills.XiantianGong do
  @moduledoc """
  武学实装「xiantian-gong」（源 xiantian-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force
  - perform/exert 路由骨架见 tmp/perf_out/xiantian_gong/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N单掌一抖，运聚先天功功力，呼啸着向$n的$l处拍去",
      "force" => 430,
      "attack" => 163,
      "parry" => 81,
      "dodge" => 87,
      "damage" => 83,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N右掌平伸，左掌运起先天功的劲力，猛地拍向$n的$l",
      "force" => 440,
      "attack" => 147,
      "parry" => 77,
      "dodge" => 85,
      "damage" => 81,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身形一展，右掌护住心脉，左掌中攻直进，贯向$n$l",
      "force" => 450,
      "attack" => 182,
      "parry" => 67,
      "dodge" => 75,
      "damage" => 93,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N运转先天真气，双掌回圈，顿时一波澎湃的气劲直袭$n",
      "force" => 480,
      "attack" => 183,
      "parry" => 85,
      "dodge" => 87,
      "damage" => 105,
      "lvl" => 0,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "xiantian-gong"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def valid_force(force),
    do: force in ["quanzhen-xinfa", "duanshi-xinfa", "suxin-jue", "yunv-xinjing", "kurong-changong", "xuanmen-neigong"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC hit_ob（combatd.c:707 force 路径）：damage_bonus>=150、自身>=180、neili>=300、
  # 空手、force 与 unarmed 都映射到本技能时，若 damage_bonus/6 > 对手 con，则给对手追加
  # (damage_bonus-100)/3 的 qi 创伤。未建模：攻击方 neili 自耗 -30、prepared 门控。
  @impl true
  def hit_ob(attacker, victim, db, _factor, _rng) do
    lvl = Map.get(attacker.skills, id(), 0)

    if db < 150 or lvl < 180 or attacker.neili < 300 or not is_nil(attacker.weapon_name) or
         Map.get(attacker.mapped, "force") != id() or
         Map.get(attacker.mapped, "unarmed") != id() do
      {0, nil}
    else
      if div(db, 6) > victim.con do
        extra = max(div(db - 100, 3), 0)
        {extra, "$N先天功的潜力发挥了出来，突然间$n只感喉咙一甜，喷出一口鲜血！\n", []}
      else
        {0, nil}
      end
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

  # LPC `valid_learn(object me)`（源 xiantian-gong.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)
    personality = personality_of(character)

    cond do
      (personality != "光明磊落") and (personality != "国士无双") ->
        {:error, "你只觉先天功正大恢弘，依自己的天性似乎难以领悟。\n"}

      Stats.int(stats) < 34 ->
        {:error, "你的先天悟性不足，难以领会高深的先天功。\n"}

      Stats.con(stats) < 34 ->
        {:error, "你的先天根骨孱弱，无法修炼高深的先天功。\n"}

      gender != "男性" ->
        {:error, "先天功乃是纯阳玄功，只有男子方可修习。\n"}

      Stats.skill(stats, "taoism") < 200 ->
        {:error, "你对道学心法的理解不够，难以领会先天功。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的基本内功火候不足，难以领会先天功。\n"}

      Stats.skill(stats, "unarmed") < 200 ->
        {:error, "你的基本拳脚火候不足，难以领会先天功。\n"}

      not is_nil(max_neili) and max_neili < 3500 ->
        {:error, "你的内力修为不足，难以领会先天功。\n"}

      (Stats.skill(stats, "taoism") < 320) and (Stats.skill(stats, "taoism") < lvl) ->
        {:error, "你对道学心法的理解不够，难以锻炼更深厚的先天功。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功水平不够，难以锻炼更深厚的先天功。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你的基本拳脚水平不够，难以锻炼更深厚的先天功。\n"}

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
      "dang" => Kantele.Combat.Skills.Performs.XiantianGong.Dang,
      "fen" => Kantele.Combat.Skills.Performs.XiantianGong.Fen,
      "hun" => Kantele.Combat.Skills.Performs.XiantianGong.Hun,
      "jian" => Kantele.Combat.Skills.Performs.XiantianGong.Jian
    }
  end

  @impl true
  def exert_list() do
    %{
      "hup" => Kantele.Combat.Skills.Performs.XiantianGong.Hup,
      "powerup" => Kantele.Combat.Skills.Performs.XiantianGong.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.XiantianGong.Shield
    }
  end

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :personality)
  defp personality_of(_character), do: nil

end

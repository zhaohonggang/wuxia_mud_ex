defmodule Kantele.Combat.Skills.Hamagong do
  @moduledoc """
  武学实装「hamagong」（源 hamagong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force
  - perform/exert 路由骨架见 tmp/perf_out/hamagong/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N忽而倒竖，一手撑住地面，身子横挺，另一掌向$n的胸口拍去",
      "force" => 310,
      "attack" => 103,
      "parry" => 21,
      "dodge" => 35,
      "damage" => 58,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N双腿微曲，右掌平伸，左掌运起蛤蟆功劲力，呼的一声推向$n",
      "force" => 332,
      "attack" => 112,
      "parry" => 37,
      "dodge" => 50,
      "damage" => 61,
      "lvl" => 180,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N闭眼逼住呼吸，猛跃而起，眼睛也不及睁开，便向$n推了出去",
      "force" => 360,
      "attack" => 122,
      "parry" => 53,
      "dodge" => 67,
      "damage" => 72,
      "lvl" => 220,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N脚步摇幌，忽然双腿一登，口中阁的一声叫喝，向$n猛然推出",
      "force" => 410,
      "attack" => 143,
      "parry" => 67,
      "dodge" => 75,
      "damage" => 81,
      "lvl" => 240,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "hamagong"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "strike"]

  @impl true
  def valid_force(force), do: force in ["baituo-xinfa"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC hit_ob（combatd.c:707 force 路径）：damage_bonus>=150、自身>=180、neili>=300、
  # 空手、force 与 strike 都映射到本技能时，若 damage_bonus/6 > 对手 con，则给对手追加
  # (damage_bonus-90)/3 的 qi 创伤。未建模：攻击方 neili 自耗 -30、prepared 门控。
  @impl true
  def hit_ob(attacker, victim, db, _factor, _rng) do
    lvl = Map.get(attacker.skills, id(), 0)

    if db < 150 or lvl < 180 or attacker.neili < 300 or not is_nil(attacker.weapon_name) or
         Map.get(attacker.mapped, "force") != id() or
         Map.get(attacker.mapped, "strike") != id() do
      {0, nil}
    else
      if div(db, 6) > victim.con do
        extra = max(div(db - 90, 3), 0)
        {extra, "$n硬承下$N一掌，霎时全身一颤，经脉受震，喷出一口鲜血！\n", []}
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

  # LPC `valid_learn(object me)`（源 hamagong.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)
    personality = personality_of(character)

    cond do
      (personality == "光明磊落") or (personality == "狡黠多变") ->
        {:error, "你心中暗道：这蛤蟆功阴毒异常，估计会伤及自身，还是别练为妙。\n"}

      Stats.str(stats) < 32 ->
        {:error, "你先天臂力孱弱，无法修炼蛤蟆功。\n"}

      Stats.con(stats) < 32 ->
        {:error, "你先天根骨太差，无法修炼蛤蟆功。\n"}

      (gender == "无性") and (Stats.skill(stats, "hamagong") > 49) ->
        {:error, "你无根无性，阴阳不调，难以领会高深的蛤蟆功。\n"}

      (Stats.skill(stats, "force") < 50) or (Stats.skill(stats, "force") < lvl) ->
        {:error, "你的基本内功火候不足，不能学蛤蟆功。\n"}

      Stats.skill(stats, "strike") < 150 ->
        {:error, "你的基本掌法火候不足，难以领会蛤蟆功。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功造诣有限，无法理解更高深的蛤蟆功。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法造诣有限，无法理解更高深的蛤蟆功。\n"}

      Stats.skill(stats, "poison") < 150 ->
        {:error, "你的基本毒技火候不足，难以领会蛤蟆功。\n"}

      not is_nil(max_neili) and max_neili < 2500 ->
        {:error, "你现在的内力修为不足，难以领会蛤蟆功。\n"}

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
      "zhen" => Kantele.Combat.Skills.Performs.Hamagong.Zhen
    }
  end

  @impl true
  def exert_list() do
    %{
      "hui" => Kantele.Combat.Skills.Performs.Hamagong.Hui,
      "powerup" => Kantele.Combat.Skills.Performs.Hamagong.Powerup,
      "reserve" => Kantele.Combat.Skills.Performs.Hamagong.Reserve,
      "tan" => Kantele.Combat.Skills.Performs.Hamagong.Tan,
      "tui" => Kantele.Combat.Skills.Performs.Hamagong.Tui
    }
  end

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil

end

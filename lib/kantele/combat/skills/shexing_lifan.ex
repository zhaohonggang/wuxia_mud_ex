defmodule Kantele.Combat.Skills.ShexingLifan do
  @moduledoc """
  武学实装「shexing-lifan」（源 shexing-lifan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shexing_lifan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身行忽而随意转动，如同水蛇一般，忽而飞身跃起，在半空中一个翻滚，招式怪异之极",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "shexing-lifan"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "shexing-lifan", 0) < 100 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "dodge", 0) + mp
      dp = div(Map.get(victim.skills, "dodge", 0) * 2, 5) + Map.get(victim.skills, "shexing-lifan", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, shexing_msg(rng)}
      else
        if mp >= 100 do
          {damage, shexing_fail_msg(rng)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp shexing_msg(rng) do
    case rng.(3) - 1 do
      0 -> "$n身形飘忽，灵巧无比，$N顿觉眼前幻象万千，这招竟然落空。\n"
      1 -> "$n猛然飞身跃起，在半空中一个翻滚，竟避开了$N这招。\n"
      _ -> "$N一招攻出，$n身形猛转，犹如灵蛇一般，轻松地避开了$N这招，令$N难以琢磨。\n"
    end
  end

  defp shexing_fail_msg(rng) do
    case rng.(4) - 1 do
      0 -> "但见$n身形飘忽不定，灵巧无比，顿时出现无数幻影，令人眼花缭乱。可是$N招式却是毫无停滞，随意施展。\n"
      1 -> "$n猛然飞身跃起，在半空中一个翻滚。然而$N早已看破其中虚实，招式忽转，袭向$n。\n"
      _ -> "但见$n身形猛转，犹如灵蛇一般，令人难以琢磨。$N微微一笑，招式猛然加快。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 120}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "guiyuan" => Kantele.Combat.Skills.Performs.ShexingLifan.Guiyuan
    }
  end
end

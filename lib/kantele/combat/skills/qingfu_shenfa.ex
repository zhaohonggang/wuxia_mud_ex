defmodule Kantele.Combat.Skills.QingfuShenfa do
  @moduledoc """
  武学实装「qingfu-shenfa」（源 qingfu-shenfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill, query_effect_dodge, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qingfu_shenfa/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "qingfu-shenfa"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "qingfu-shenfa", 0) < 100 or rng.(2) - 1 != 1 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "dodge", 0) + mp
      dp = div(Map.get(victim.skills, "dodge", 0), 2) + Map.get(victim.skills, "qingfu-shenfa", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, qingfu_msg(rng)}
      else
        if mp >= 100 do
          {damage, qingfu_fail_msg(rng)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp qingfu_msg(rng) do
    case rng.(2) - 1 do
      0 -> "只见$n长啸一声犹如一只蝙蝠一样纵身而起，于半空倒立，$N这招却扑了个空。\n"
      _ -> "但见$n身法轻盈无比，忽然跃高忽而落下，令$N完全无从攻击。\n"
    end
  end

  defp qingfu_fail_msg(rng) do
    case rng.(2) - 1 do
      0 -> "只见$n长啸一声犹如一只蝙蝠一样纵身而起，于半空倒立，可是$N精通易理，将其中虚实辨得清清楚楚。\n"
      _ -> "但见$n身法轻盈无比，忽然跃高忽而落下，$N不假思索，飞身出招，更是巧妙无方。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "move"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 55}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

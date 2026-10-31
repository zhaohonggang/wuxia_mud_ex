defmodule Kantele.Combat.Skills.WaiBagua do
  @moduledoc """
  武学实装「wai-bagua」（源 wai-bagua.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_parry, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wai_bagua/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "wai-bagua"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "wai-bagua", 0) < 100 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "force", 0) + mp
      dp = div(Map.get(victim.skills, "parry", 0), 2) + Map.get(victim.skills, "wai-bagua", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < div(dp * 3, 4) do
        {0, wai_bagua_msg(rng)}
      else
        if mp >= 100 do
          {damage, wai_bagua_fail_msg(rng)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp wai_bagua_msg(rng) do
    case rng.(3) - 1 do
      0 -> "$n身形忽然按照八卦方位转个不停，$N这一招竟然无从下手。\n"
      1 -> "$n单掌利用八卦四方的巧劲轻轻一托，$N登时拿捏不准力道，不禁泛起一阵有心无力的感觉。\n"
      _ -> "$N一招眼看击中了$n，然而$n轻轻一格，将$N的攻击利用八卦巧劲化于无形。\n"
    end
  end

  defp wai_bagua_fail_msg(rng) do
    case rng.(2) - 1 do
      0 -> "$n轻轻挥拳阻搁，暗含八卦巧劲，可$N精通易理，丝毫不假思索，随即反身出招。\n"
      _ -> "$n按照八卦阵方位转个不停，可却见$N一声冷笑，顺手便是一招，恰好破尽玄机。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "zhen" => Kantele.Combat.Skills.Performs.WaiBagua.Zhen
    }
  end
end

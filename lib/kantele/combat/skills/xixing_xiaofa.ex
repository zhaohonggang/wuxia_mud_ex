defmodule Kantele.Combat.Skills.XixingXiaofa do
  @moduledoc """
  武学实装「xixing-xiaofa」（源 xixing-xiaofa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_damage, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xixing_xiaofa/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "xixing-xiaofa"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "xixing-xiaofa", 0) < 80 or attacker.jiali < 1 do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0)
      dp = Map.get(victim.skills, "force", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, xixing_xiao_msg(rng)}
      else
        {damage, nil}
      end
    end
  end

  defp xixing_xiao_msg(rng) do
    case rng.(3) - 1 do
      0 -> "$N只觉得内力源源而泻，转如地下，不由得大吃一惊。\n"
      1 -> "$N只觉得发出的内力犹如石沉大海，被$n尽数转如地下。\n"
      _ -> "$N不住催动内力，但是只觉得$n竟似毫不费力。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

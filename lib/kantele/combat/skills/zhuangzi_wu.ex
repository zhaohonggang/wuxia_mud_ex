defmodule Kantele.Combat.Skills.ZhuangziWu do
  @moduledoc """
  武学实装「zhuangzi-wu」（源 zhuangzi-wu.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_dodge, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhuangzi_wu/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "zhuangzi-wu"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "zhuangzi-wu", 0) < 100 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "dodge", 0) + mp
      dp = div(Map.get(victim.skills, "dodge", 0), 2) + Map.get(victim.skills, "zhuangzi-wu", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, zhuangzi_msg(rng)}
      else
        if mp >= 100 do
          {damage, zhuangzi_fail_msg(rng)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp zhuangzi_msg(rng) do
    case rng.(4) - 1 do
      0 -> "只见$n足尖在地面轻轻一点，整个身子顿时凌空飘起，轻而易举躲开了$N的招式。\n"
      1 -> "可是$n蛮腰微微一颤，步法宛如行云流水，轻飘飘的落在一旁，顿时使$N的攻势落空。\n"
      2 -> "但见$n微微一笑，身形轻展，整个人竟踏空飘起，待$N一招击空后，又翩翩而落，晃至$N跟前。\n"
      _ -> "可$n竟丝毫不理会$N的招数，径自迎面奔上，幻出无数倩影翩翩起舞，$N勘不透虚实，唯有收招。\n"
    end
  end

  defp zhuangzi_fail_msg(rng) do
    case rng.(4) - 1 do
      0 -> "只见$n足尖轻点地面，凌空飘然而起，可$N遁影擒踪，一声冷笑，随即飞身扑上。\n"
      1 -> "$n蛮腰微微一颤，步法宛如行云流水，轻飘而落，可$N毫不理会，反手又攻出一招。\n"
      2 -> "$n微微一笑，身形轻展，整个人竟踏空飘起，可又见$N也随即飘起，在半空攻出数招。\n"
      _ -> "但见$n身形一展，幻出无数倩影翩翩起舞，可$N不假思索攻出一招，正是实影所在。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["dodge"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 60}

  # LPC `valid_learn(object me)`（源 zhuangzi-wu.c）
  # LPC: lvl = query_skill(); if (lvl > 300) lvl = 300; if (family=="红花会") lvl -= 60;
  @impl true
  def valid_learn(stats, character) do
    family_name = family_name_of(character)
    max_neili = max_neili_of(character)

    base = min(Stats.skill(stats, id()), 300)
    lvl = if family_name == "红花会", do: base - 60, else: base

    cond do
      Stats.dex(stats) < 26 ->
        {:error, "你先天身法太差，无法学习庄子舞。\n"}

      not is_nil(max_neili) and max_neili < 2400 + lvl * 15 ->
        {:error, "你按照庄子舞所示的步法随意走了两下，顿时只感头晕目眩，看来是内力不济。\n"}

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
      "hua" => Kantele.Combat.Skills.Performs.ZhuangziWu.Hua
    }
  end

  # LPC `me->query("family/family_name")`：无门派时 LPC 返回 0，
  # `0 != "少林派"` 为真 → 拦；nil 行为一致，无需额外守卫。
  defp family_name_of(%{meta: %{family: family}}) when is_map(family),
    do: Map.get(family, :name) || Map.get(family, "name")
  defp family_name_of(_character), do: nil

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

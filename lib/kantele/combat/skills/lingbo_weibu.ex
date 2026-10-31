defmodule Kantele.Combat.Skills.LingboWeibu do
  @moduledoc """
  凌波微步（对照 `kungfu/skill/lingbo-weibu.c`）

  轻功载体：`valid_enable("dodge")`。

  绝招实现见 `lib/kantele/combat/skills/performs/lingbo_weibu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=3000+lvl*15 门槛本版未代理（引擎
    `valid_learn/1` 只拿 stats，无 vitals），仅以 dex>=30 校验；
  - LPC `valid_damage`/`query_effect_dodge` 被动（身法幻影抵消伤害）与
    `dodge_msg` 未建模。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "lingbo-weibu"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "lingbo-weibu", 0) < 100 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "dodge", 0) + mp
      dp = div(Map.get(victim.skills, "dodge", 0), 2) + Map.get(victim.skills, "lingbo-weibu", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, lingbo_msg(rng)}
      else
        if mp >= 100 do
          {damage, lingbo_fail_msg(rng)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp lingbo_msg(rng) do
    case rng.(4) - 1 do
      0 -> "$n身子轻轻晃动，$N眼前顿时出现了无数个$n的幻影，令$N完全无法辨出虚实。\n"
      1 -> "$n往旁边歪歪斜斜的迈出一步，却恰好令$N的攻击失之毫厘。\n"
      2 -> "$N这一招来的好快，然后$n一闪，似乎不费半点力气，却将$N这一招刚好避开。\n"
      _ -> "$n轻轻一跃，已不见了踪影，$N心中大骇，却又见$n擦肩奔过，当真令人思索菲仪。\n"
    end
  end

  defp lingbo_fail_msg(rng) do
    case rng.(4) - 1 do
      0 -> "只见$n微微一笑，身子轻轻晃动，顿时出现了无数个$n的幻影，可是$N精通易理，将其中虚实辨得清清楚楚。\n"
      1 -> "$n往旁边歪歪斜斜的迈出一步，然而$N错步跟随，方位毫厘不差。\n"
      2 -> "$n一闪，似乎不费半点力气，却将$N这一招刚好避开，可是$N招中有招，进攻却是不止。\n"
      _ -> "但见$n轻轻一跃，已不见了踪影，$N不假思索，反身出招，更是巧妙无方。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage == "dodge"

  @impl true
  def valid_learn(stats) do
    if stats.dex < 30 do
      {:error, "你先天身法太差，无法学习凌波微步。\n"}
    else
      :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"ling" => Kantele.Combat.Skills.Performs.LingboWeibu.Ling}
  end
end

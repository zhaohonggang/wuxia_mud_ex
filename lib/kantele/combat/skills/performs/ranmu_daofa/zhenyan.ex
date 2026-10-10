defmodule Kantele.Combat.Skills.Performs.RanmuDaofa.Zhenyan do
  @moduledoc """
  燃木真焰「zhenyan」（对照 `kungfu/skill/ranmu-daofa/zhenyan.c`）

  燃木刀法杀伐架势：`attack+skill*2/5`、`defense+skill*2/5`、
  `damage+skill/4`，持续 `skill` 秒，到期由 `combat/buff-expire` 回收；
  战斗中忙乱 2；扣 400 内力。

  差异（TODO(migrate)）：
  - LPC 要求激发少林内功（hunyuan-yiqi/yijinjing/luohan-fumogong）与
    燃木刀法为刀法、持刀，本版以 mapped/custom 门槛表达，武器存在性
    以装备检查近似（skill_type blade）。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "ranmu-daofa/zhenyan",
      kind: :perform,
      gates: [
        {:perform_known, "ranmu-daofa/zhenyan", "你所使用的外功中没有这种功能。\n"},
        {:custom, &weapon_blade?/1, "你必须用刀法施展。\n"},
        {:no_buff, "zhen_yan", "「燃木真焰」无法连续施展。\n"},
        {:skill_min, "ranmu-daofa", 180, "你的燃木刀法修为不够，难以施展「燃木真焰」。\n"},
        {:max_neili_min, 2500, "你的内力修为不足，难以施展「燃木真焰」。\n"},
        {:custom, &shaolin_force?/1, "你现在没有激发少林内功为内功，难以施展「燃木真焰」。\n"},
        {:mapped, "blade", "ranmu-daofa", "你没有激发燃木刀法为刀法，难以施展「燃木真焰」。\n"},
        {:neili_min, 500, "你现在的真气不足，难以施展「燃木真焰」。\n"}
      ],
      costs: %{neili: 400},
      effects: [
        {:buff, "zhen_yan",
         %{
           attack: {:div, {:mul, {:skill, "ranmu-daofa"}, 2}, 5},
           defense: {:div, {:mul, {:skill, "ranmu-daofa"}, 2}, 5},
           damage: {:div, {:skill, "ranmu-daofa"}, 4}
         }}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "ranmu-daofa"},
      expire_message: "你经过调气养息，又可以继续施展「燃木真焰」了。\n",
      message:
        "$N双手持刀，对天咆哮，所施正是燃木刀法绝学「燃木真焰」。霎时呼啸声大作，但见一股澎湃无比的罡劲自$N刀尖涌出。\n"
    }

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  defp weapon_blade?(ctx), do: match?(%{skill_type: "blade"}, Combat.weapon(ctx.combat))

  defp shaolin_force?(ctx),
    do: Stats.mapped(ctx.stats, "force") in ["hunyuan-yiqi", "yijinjing", "luohan-fumogong"]
end
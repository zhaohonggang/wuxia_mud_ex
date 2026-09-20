defmodule Kantele.Combat.Skills.Performs.RiyueLun.Yuan do
  @moduledoc """
  圆满势「yuan」（对照 `kungfu/skill/riyue-lun/yuan.c`）

  日月轮防御架势：`parry+skill/3`，持续 `skill/2` 秒，到期由
  `combat/buff-expire` 回收；战斗中忙乱 2；扣 200 内力。

  差异（TODO(migrate)）：
  - LPC 要求激发龙象般若功/日月轮法并持锤，本版以 mapped/custom 门槛
    表达，武器存在性以装备检查近似（skill_type hammer）。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "riyue-lun/yuan",
      kind: :perform,
      gates: [
        {:perform_known, "riyue-lun/yuan", "你所使用的外功中没有这种功能。\n"},
        {:no_buff, "yuan_man", "你现在正在施展「圆满势」。\n"},
        {:custom, &weapon_hammer?/1, "你所使用的武器不对，难以施展「圆满势」。\n"},
        {:mapped, "hammer", "riyue-lun", "你没有激发日月轮法，难以施展「圆满势」。\n"},
        {:mapped, "force", "longxiang-gong", "你没有激发龙象般若功，难以施展「圆满势」。\n"},
        {:skill_min, "riyue-lun", 120, "你的日月轮法火候不足，难以施展「圆满势」。\n"},
        {:skill_min, "force", 180, "你的内功火候不足，难以施展「圆满势」。\n"},
        {:max_neili_min, 1500, "你的内力修为不足，难以施展「圆满势」。\n"},
        {:neili_min, 300, "你现在的真气不足，难以施展「圆满势」。\n"}
      ],
      costs: %{neili: 200},
      effects: [
        {:buff, "yuan_man", %{parry: {:div, {:skill, "riyue-lun"}, 3}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:div, {:skill, "riyue-lun"}, 2},
      expire_message: "你的「圆满势」运行完毕，将内力收回丹田。\n",
      message: "$N吐气扬声，施出日月轮法「圆满势」，手中兵刃运转如飞，迅速护住周身要害。\n"
    }

  alias Kantele.Character.Combat

  defp weapon_hammer?(ctx), do: match?(%{skill_type: "hammer"}, Combat.weapon(ctx.combat))
end
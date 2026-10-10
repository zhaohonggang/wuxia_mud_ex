defmodule Kantele.Combat.Skills.Performs.TaijiJian.Sui do
  @moduledoc """
  随字诀「sui」（对照 `kungfu/skill/taiji-jian/sui.c`）

  太极剑防御架势：`defense+skill/3`、`attack-skill/6`，持续 `skill/3`
  秒，到期由 `combat/buff-expire` 回收（负攻击加成同样回收）；战斗中
  忙乱 3；扣 100 内力。

  差异（TODO(migrate)）：
  - LPC 要求持剑并激发太极剑法，本版以技能激发门槛为主，武器存在性以
    装备检查近似（skill_type sword）。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "taiji-jian/sui",
      kind: :perform,
      gates: [
        {:perform_known, "taiji-jian/sui", "你所使用的外功中没有这种功能。\n"},
        {:no_buff, "tjj_sui", "你现在正在施展「随字诀」。\n"},
        {:custom, &weapon_sword?/1, "你使用的武器不对，难以施展「随字诀」。\n"},
        {:skill_min, "taiji-jian", 60, "你的太极剑法不够娴熟，难以施展「随字诀」。\n"},
        {:mapped, "sword", "taiji-jian", "你没有激发太极剑法，难以施展「随字诀」。\n"},
        {:neili_min, 300, "你现在的真气不足，难以施展「随字诀」。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "tjj_sui",
         %{
           defense: {:div, {:skill, "taiji-jian"}, 3},
           attack: {:sub, 0, {:div, {:skill, "taiji-jian"}, 6}}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:div, {:skill, "taiji-jian"}, 3},
      expire_message: "你的「随字诀」运行完毕，将内力收回丹田。\n",
      message: "$N使出太极剑法「随」字诀，手中剑圆转不定，剑圈逐渐缩小将周身护住。\n"
    }

  alias Kantele.Character.Combat

  defp weapon_sword?(ctx), do: match?(%{skill_type: "sword"}, Combat.weapon(ctx.combat))
end
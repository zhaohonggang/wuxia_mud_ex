defmodule Kantele.Combat.Skills.Performs.BanruoZhang.Feng do
  @moduledoc """
  封魔「feng」（对照 `kungfu/skill/banruo-zhang/feng.c`）

  般若掌防御架势：`dodge+skill/3`、`attack-skill/4`（守强攻弱），
  持续 `skill/4` 秒，到期由 `combat/buff-expire` 回收；战斗中忙乱 2；
  扣 100 内力。

  差异（TODO(migrate)）：
  - LPC `remove_effect` 有到期文案与加减回卷，本版统一走 buff 到期
    回收（`expire_message` 文本沿用）。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "banruo-zhang/feng",
      kind: :perform,
      gates: [
        {:perform_known, "banruo-zhang/feng", "你所使用的外功中没有这种功能。\n"},
        {:skill_min, "banruo-zhang", 60, "你的般若掌法不够娴熟，不会使用「封魔」。\n"},
        {:neili_min, 200, "你的真气不够，无法使用「封魔」。\n"},
        {:no_buff, "brz_feng", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "brz_feng",
         %{
           attack: {:sub, 0, {:div, {:skill, "banruo-zhang"}, 4}},
           dodge: {:div, {:skill, "banruo-zhang"}, 3}
         }}
      ],
      busy: {:if_fighting, 2},
      duration: {:div, {:skill, "banruo-zhang"}, 4},
      expire_message: "你的般若掌「封魔」运行完毕，将内力收回丹田。\n",
      message: "$N使出般若掌「封魔」式，双掌翻飞将周身护住。\n"
    }
end
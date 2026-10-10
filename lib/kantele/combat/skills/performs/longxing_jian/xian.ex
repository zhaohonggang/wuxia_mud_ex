defmodule Kantele.Combat.Skills.Performs.LongxingJian.Xian do
  @moduledoc """
  神龙再现「xian」（对照 `kungfu/skill/longxing-jian/xian.c`）

  战斗中自我增益：`attack+2`、`dodge+1`、`parry+1`，并在 `apply/xian`
  计数 +1（<50 可叠放，无到期回收）；忙乱 1；扣 100 内力。

  差异（TODO(migrate)）：
  - LPC 通过 `add_temp("xian", 1)` 计数、上限 50 拒绝连用，本版以
    buff 无到期 + custom 门槛（temp.xian < 50）表达；
  - LPC 要求战斗中（`is_fighting`），本版 custom 门槛保留。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "longxing-jian/xian",
      kind: :perform,
      gates: [
        {:perform_known, "longxing-jian/xian", "你所使用的外功中没有这种功能。\n"},
        {:custom, &fighting?/1, "神龙再现只能在战斗中使用。\n"},
        {:skill_min, "longxing-jian", 150, "你的龙形剑法不够娴熟，不会使用神龙再现。\n"},
        {:skill_min, "buddhism", 150, "你的佛法修为不够娴熟，不会使用神龙再现。\n"},
        {:neili_min, 300, "你已经精疲力竭，内力不够了。\n"},
        {:custom, &xian_not_saturated?/1, "你已经念佛念得太久了，神龙已经厌倦了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:temp, %{attack: 2, dodge: 1, parry: 1, xian: 1}}
      ],
      busy: 1,
      message: "$N口中念念有词，神龙从天而降，钻入$N体内！\n"
    }

  alias Kantele.Character.Combat

  defp fighting?(ctx), do: Combat.fighting?(ctx.combat)

  defp xian_not_saturated?(ctx), do: Map.get(ctx.combat.temp, :xian, 0) < 50
end
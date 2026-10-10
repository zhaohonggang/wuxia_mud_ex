defmodule Kantele.Combat.Skills.Performs.JinzhongZhao.Zhao do
  @moduledoc """
  金钟罩「zhao」（对照 `kungfu/skill/jinzhong-zhao/zhao.c`）

  自我增益：以 `skill = force + jinzhong-zhao/2` 为当量，`armor+skill/2`、
  `force+skill/4`，持续 `skill` 秒，到期由 `combat/buff-expire` 回收；
  战斗中忙乱 3；扣 300 内力。与金刚不坏/神魔金身互斥。

  差异（TODO(migrate)）：
  - LPC `apply/force` 键不在引擎 @applies_keys 白名单，本版仅记 buff 状态、
    `force` 加成不参与战力计算；
  - LPC 神魔金身 `special/jinshen` 互斥未建模（引擎无对应 buff 键）；
  - `me->receive_damage("qi", 0)` 零伤调用省略。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "jinzhong-zhao/zhao",
      kind: :perform,
      gates: [
        {:perform_known, "jinzhong-zhao/zhao", "你所使用的外功中没有这种功能。\n"},
        {:neili_min, 400, "你的内力不够。\n"},
        {:skill_min, "jinzhong-zhao", 150, "你的[金钟罩]修为不够。\n"},
        {:no_buff, "jinzhongzhao", "你已经运起[金钟罩]作为护体神功了。\n"},
        {:no_buff, "jingangbuhuai", "你已经运起金刚不坏护体神功了。\n"}
      ],
      costs: %{neili: 300},
      effects: [
        {:buff, "jinzhongzhao", %{armor: {:div, total(), 2}, force: {:div, total(), 4}}}
      ],
      busy: {:if_fighting, 3},
      duration: total(),
      expire_message: "你的[金钟罩]护体神功运行完毕，将内力收回丹田。\n",
      message: "$N仰天暴喝一声，全身猛然一抖，一股无形真气迅速游经八脉罩住全身，刹时间四周飞沙走石，烟尘滚滚！\n"
    }

  defp total(), do: {:add, {:skill, "force"}, {:div, {:skill, "jinzhong-zhao"}, 2}}
end
defmodule Kantele.Combat.Skills.Performs.JingangBuhuaiti.Jingang do
  @moduledoc """
  金刚不坏「jingang」（对照 `kungfu/skill/jingang-buhuaiti/jingang.c`）

  自我增益：以 `skill = force + jingang-buhuaiti/2` 为当量，`armor+skill/2`、
  `force+skill/3`，持续 `skill` 秒，到期由 `combat/buff-expire` 回收；
  战斗中忙乱 2；扣 200 内力。与金钟罩/神魔金身互斥。

  差异（TODO(migrate)）：
  - LPC 源文件 `query_skill("jingang-buhuai", 1)` 笔误（无关技能）、实际只取
    force 当量；本版按意图实现 `force + jingang-buhuaiti/2`；
  - LPC `apply/force` 键不在引擎 @applies_keys 白名单，本版仅记 buff 状态、
    `force` 加成不参与战力计算（同批次 2 xuanming shield 收敛惯例）；
  - `me->receive_damage("qi", 0)` 零伤调用省略。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "jingang-buhuaiti/jingang",
      kind: :perform,
      gates: [
        {:perform_known, "jingang-buhuaiti/jingang", "你所使用的外功中没有这种功能。\n"},
        {:neili_min, 300, "你的内力不够。\n"},
        {:skill_min, "jingang-buhuaiti", 100, "你的金刚不坏护体神功修为不够。\n"},
        {:no_buff, "jingangbuhuai", "你已经运起金刚不坏护体神功了。\n"},
        {:no_buff, "jinzhongzhao", "你已经运起[金钟罩]作为护体神功了。\n"}
      ],
      costs: %{neili: 200},
      effects: [
        {:buff, "jingangbuhuai", %{armor: {:div, total(), 2}, force: {:div, total(), 3}}}
      ],
      busy: {:if_fighting, 2},
      duration: total(),
      expire_message: "你的金刚不坏护体神功运行完毕，将内力收回丹田。\n",
      message: "$N高呼佛号，全身肌肉紧缩，霎那间皮肤竟犹如镀金一般，发出灿灿金光。\n"
    }

  defp total(), do: {:add, {:skill, "force"}, {:div, {:skill, "jingang-buhuaiti"}, 2}}
end
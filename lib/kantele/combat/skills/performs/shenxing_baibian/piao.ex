defmodule Kantele.Combat.Skills.Performs.ShenxingBaibian.Piao do
  @moduledoc """
  虚无缥缈「piao」（对照 `kungfu/skill/shenxing-baibian/piao.c`）

  神行百变身法：`dodge+skill`，持续 `skill/10` 秒，到期由
  `combat/buff-expire` 回收；扣 100 内力（LPC 无 busy）。

  差异（TODO(migrate)）：
  - LPC 要求把神行百变激发为轻功，本版以 mapped 门槛表达。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "shenxing-baibian/piao",
      kind: :perform,
      gates: [
        {:perform_known, "shenxing-baibian/piao", "你所使用的外功中没有这种功能。\n"},
        {:skill_min, "shenxing-baibian", 60, "你的神行百变不够娴熟，不会使用「虚无缥缈」。\n"},
        {:mapped, "dodge", "shenxing-baibian", "你没有使用神行百变，无法施展「虚无缥缈」。\n"},
        {:no_buff, "shenxing", "你已经运起「虚无缥缈」了。\n"},
        {:neili_min, 60, "你现在真气不够，无法施展「虚无缥缈」。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shenxing", %{dodge: {:skill, "shenxing-baibian"}}}
      ],
      busy: 0,
      duration: {:div, {:skill, "shenxing-baibian"}, 10},
      expire_message: "你的「虚无缥缈」运功完毕，将内力收回丹田。\n",
      message:
        "$N将全身的内力旋转震动，身形东一溜，西一晃，忽又左右摇摆作势欲发，虚虚实实，飘渺不定。\n"
    }
end
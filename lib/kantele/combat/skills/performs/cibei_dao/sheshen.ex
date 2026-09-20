defmodule Kantele.Combat.Skills.Performs.CibeiDao.Sheshen do
  @moduledoc """
  舍身喂鹰「sheshen」（对照 `kungfu/skill/cibei-dao/sheshen.c`）

  自我增益：把浑身功力运到刀上，`attack+skill/3`、`dodge-skill/5`
  （以柔破钢的代价），持续 `skill/4` 秒，到期由 `combat/buff-expire` 回收；
  战斗中忙乱 2；扣 100 内力。

  差异（TODO(migrate)）：
  - LPC 文案夹带武器名（`weapon->name()`），本版取固定文案；
  - `add_temp("apply/dodge", -skill/5)` 的负闪避加成经 buff 负值表达，
    到期自动回升。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "cibei-dao/sheshen",
      kind: :perform,
      gates: [
        {:perform_known, "cibei-dao/sheshen", "你所使用的外功中没有这种功能。\n"},
        {:skill_min, "cibei-dao", 60, "你的慈悲刀法不够娴熟，不会使用「舍身喂鹰」。\n"},
        {:neili_min, 200, "你的真气不够，无法使用「舍身喂鹰」。\n"},
        {:no_buff, "cbd_sheshen", "你已经在运功中了。\n"},
        {:custom, &weapon_blade?/1, "你使用的武器不对。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "cbd_sheshen",
         %{
           attack: {:div, {:skill, "cibei-dao"}, 3},
           dodge: {:sub, 0, {:div, {:skill, "cibei-dao"}, 5}}
         }}
      ],
      busy: {:if_fighting, 2},
      duration: {:div, {:skill, "cibei-dao"}, 4},
      expire_message: "你的「舍身喂鹰」运行完毕，将内力收回丹田。\n",
      message: "$N使出慈悲刀法「舍身喂鹰」，将浑身的功力都运到手中的刀上，刀势一往无前！\n"
    }

  alias Kantele.Character.Combat

  defp weapon_blade?(ctx) do
    match?(%{skill_type: "blade"}, Combat.weapon(ctx.combat))
  end
end
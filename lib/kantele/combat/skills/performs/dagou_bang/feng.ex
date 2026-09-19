defmodule Kantele.Combat.Skills.Performs.DagouBang.Feng do
  @moduledoc """
  封字诀「feng」（对照 `kungfu/skill/dagou-bang/feng.c`）

  自我增益：杖、打狗棒法>=120、激发 staff=打狗棒法、force>=180、neili>=200。
  扣 150 内力，临时 `parry + 打狗棒法/3`，持续 `打狗棒法/2` 秒；战斗中 busy 2。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  @name "「封字诀」"

  def spec do
    %Spec{
      id: "dagou-bang/feng",
      kind: :perform,
      gates: [
        {:perform_known, "dagou-bang/feng", "你所使用的外功中没有这种功能。\n"},
        {:custom, &gate_weapon/1, "你使用的武器不对，难以施展#{@name}。\n"},
        {:no_buff, "feng_zijue", "你现在正在施展#{@name}。\n"},
        {:skill_min, "dagou-bang", 120, "你打狗棒法不够娴熟，难以施展#{@name}。\n"},
        {:custom, &gate_mapped/1, "你没有激发打狗棒法，难以施展#{@name}。\n"},
        {:custom, &gate_force/1, "你的内功火候不足，难以施展#{@name}。\n"},
        {:neili_min, 200, "你现在的真气不够，难以施展#{@name}。\n"}
      ],
      costs: %{neili: 150},
      effects: [
        {:buff, "feng_zijue", %{parry: {:div, {:skill, "dagou-bang"}, 3}}}
      ],
      duration: {:div, {:skill, "dagou-bang"}, 2},
      expire_message: "你的「封字诀」施展完毕，将内力收回丹田。\n",
      message: &message/1,
      busy: {:if_fighting, 2}
    }
  end

  defp gate_weapon(ctx) do
    match?(%{skill_type: "staff"}, Combat.weapon(ctx.character.meta.combat))
  end

  defp gate_mapped(ctx) do
    Stats.mapped(ctx.stats, "staff") == "dagou-bang"
  end

  defp gate_force(ctx) do
    Stats.skill(ctx.stats, "force") >= 180
  end

  defp message(ctx) do
    wp =
      case Combat.weapon(ctx.character.meta.combat) do
        %{name: name} -> name
        _ -> "兵器"
      end

    "$N使出打狗棒法「封」字诀，手中#{wp}疾速舞动，幻出许许棒影护住周身。\n"
  end
end

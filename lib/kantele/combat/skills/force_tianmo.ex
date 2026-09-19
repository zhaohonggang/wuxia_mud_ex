defmodule Kantele.Combat.Skills.Force.Tianmo do
  @moduledoc """
  天魔解体大法（对照 `kungfu/skill/force/tianmo.c`）

  极限门槛：str>=30 或 con>=30、neili>=8000、shen<=-10000000、
  force>=300 且 martial-cognize>=300、非天魔状态。
  设 neili=0；扣 qi/jing 及 eff_qi/eff_jing（skill+shen_lvl+rand(1000)）；
  临时 str/int/con/dex 各 +自身值、attack +count、damage/unarmed_damage +str*3、
  每个 mapped 武学技能 +count/2（count=(shen_lvl+skill)/4），busy 3。

  LPC 为久效 temp（无 remove_effect/duration），本引擎按 Buff "tianmo" 记录
  （heal 等以此为判定），不设到期时长。
  TODO(migrate): custom 效果不接受注入 rng，伤害随机用 :rand.uniform；
  temp 键收敛为 atom 攻防当量 + 技能名（技能键暂未被消费端读取）。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/tianmo",
      kind: :exert,
      gates: [
        {:no_buff, "tianmo", "你已经在运功中了。\n"},
        {:custom, &gate_attributes/1, "你的资质不适合使用「天魔解体大法」。\n"},
        {:neili_min, 8000, "你的内力不够!\n"},
        {:custom, &gate_shen/1, "你还没有入魔，无法使用「天魔解体大法」。\n"},
        {:custom, &gate_skill_levels/1, "你的修行还不够,无法使用「天魔解体大法」。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_tianmo/1}
      ],
      busy: {:if_fighting, 3},
      message: "$N蓦地大叫一声，喷出一口鲜血，正是天下闻名的「天魔解体大法」。\n"
    }
  end

  defp gate_attributes(ctx) do
    stats = ctx.character.meta.stats
    (stats.str || 0) >= 30 || (stats.con || 0) >= 30
  end

  defp gate_shen(ctx) do
    (ctx.character.meta.stats.shen || 0) <= -10_000_000
  end

  defp gate_skill_levels(ctx) do
    Stats.skill(ctx.stats, "force") >= 300 && Stats.skill(ctx.stats, "martial-cognize") >= 300
  end

  defp effect_tianmo(state) do
    char = state.character
    vitals = char.meta.vitals
    stats = char.meta.stats
    combat = char.meta.combat

    skill = Stats.skill(stats, "force")
    shen = stats.shen || 0
    shen_lvl = :math.pow(-shen * 1.0, 1.0 / 3.0) |> floor()
    count = div(shen_lvl + skill, 4)
    skills = stats.mapped |> Map.values() |> Enum.uniq()

    dmg = skill + shen_lvl + :rand.uniform(1000)

    new_vitals = %{
      vitals
      | neili: 0,
        qi: max(vitals.qi - dmg, 1),
        max_qi: max(vitals.max_qi - dmg, 1),
        jing: max(vitals.jing - dmg, 1),
        max_jing: max(vitals.max_jing - dmg, 1)
    }

    str = stats.str || 0

    applies =
      %{
        str: str,
        int: stats.int || 0,
        con: stats.con || 0,
        dex: stats.dex || 0,
        attack: count,
        damage: str * 3,
        unarmed_damage: str * 3
      }

    applies = Enum.reduce(skills, applies, fn skill_id, acc -> Map.put(acc, skill_id, div(count, 2)) end)

    buff =
      %Buff{
        key: "tianmo",
        applies: Enum.reduce(applies, %{}, fn {key, value}, acc -> Map.put(acc, key, -value) end)
      }

    new_combat =
      combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)

    new_char = %{char | meta: %{char.meta | vitals: new_vitals, combat: new_combat}}

    %{state | character: new_char}
  end
end
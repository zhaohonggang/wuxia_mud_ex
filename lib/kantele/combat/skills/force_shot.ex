defmodule Kantele.Combat.Skills.Force.Shot do
  @moduledoc """
  弹毒（对照 `kungfu/skill/force/shot.c`）

  仅限特定内功：修罗/化功/蛤蟆/神农/华血；
  force>=150、poison>=100、throwing>=100、neili>=300；
  需 hand 中毒药、目标有效、非 no_fight/skybook、非 die_guard/比武；
  内力对抗，成功施加毒药效果、busy 2。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @allowed_forces ~w(xiuluo-yinshagong huagong-dafa hamagong shennong-xinjing huaxue-shengong)

  @impl true
  def id(), do: "force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"shot" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/shot",
      kind: :exert,
      gates: [
        {:custom, &gate_allowed_force/1, "你所学的内功中没有这种功能。\n"},
        {:custom, &gate_force_level/1, "你的内功修为不够。\n"},
        {:custom, &gate_skill_level/1, "你的基本毒技/暗器火候不够。\n"},
        {:custom, &gate_room_ok/1, "在这里不能攻击他人。\n"},
        {:neili_min, 300, "你的真气不够。\n"},
        {:custom, &gate_handing_poison/1, "你得先准备(hand)好毒药再说。\n"},
        {:custom, &gate_valid_target/1, "你想攻击谁？\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_shot/1}
      ],
      busy: {:if_fighting, 1 + :rand.uniform(3)},
      message: fn ctx ->
        du =
          ctx.character.meta.inventory |> Enum.find(& &1.handing) ||
            %{name: "毒药"}

        "$N一声冷笑，默运#{to_chinese(ctx.stats.mapped.force)}内劲，手指粘住#{du.name}对准#{ctx.target.name}「嗖」的弹射了出去。\n"
      end
    }
  end

  defp gate_allowed_force(ctx),
    do: if(ctx.stats.mapped.force in @allowed_forces, do: :ok, else: {:error, "你所学的内功中没有这种功能。\n"})

  defp gate_force_level(ctx),
    do: if(Stats.skill(ctx.stats, "force") >= 150, do: :ok, else: {:error, "你的内功修为不够。\n"})

  defp gate_skill_level(ctx) do
    if Stats.skill(ctx.stats, "poison") >= 100 && Stats.skill(ctx.stats, "throwing") >= 100,
      do: :ok,
      else: {:error, "你的基本毒技/暗器火候不够。\n"}
  end

  defp gate_room_ok(ctx),
    do: if(not (ctx.room.no_fight || ctx.room.skybook), do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp gate_handing_poison(ctx) do
    du = ctx.character.meta.inventory |> Enum.find(& &1.handing)
    if du && du.meta.poison, do: :ok, else: {:error, "你手中所拿的不是毒药，无法弹射。\n"}
  end

  defp gate_valid_target(ctx) do
    if ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive? &&
         not ctx.target.meta.conditions.die_guard && not ctx.target.meta.combat.competitor,
       do: :ok,
       else: {:error, "无效目标。\n"}
  end

  defp effect_shot(state) do
    char = state.character
    target = state.target
    du = char.meta.inventory |> Enum.find(& &1.handing)

    an = char.meta.vitals.max_neili + div(char.meta.vitals.neili, 2)
    dn = target.meta.vitals.max_neili + div(target.meta.vitals.neili, 2)

    if div(an, 2) + :rand.uniform(an) < dn * 2 / 3 do
      # Target resists
      target = target
    else
      ap =
        Stats.skill(char.meta.stats, "force") + Stats.skill(char.meta.stats, "poison") +
          Stats.skill(char.meta.stats, "throwing")

      dp =
        Stats.skill(target.meta.stats, "dodge") + Stats.skill(target.meta.stats, "parry") +
          Stats.skill(target.meta.stats, "martial-cognize")

      if div(ap, 2) + :rand.uniform(ap) > dp do
        # Apply poison
        poison_type = du.meta.poison_type

        target = %{
          target
          | meta: %{
              target.meta
              | conditions: Map.put(target.meta.conditions || %{}, poison_type, du.meta.poison)
            }
        }

        if not target.meta.combat.busy > 0,
          do: target = %{target | meta: %{target.meta | combat: %{target.meta.combat | busy: 2}}}
      end
    end

    # Consume poison
    new_du =
      if du.meta.amount do
        %{du | meta: %{du.meta | amount: du.meta.amount - 1}}
      else
        nil
      end

    new_inventory =
      Enum.map(char.meta.inventory, fn item ->
        if item == du, do: new_du, else: item
      end)

    new_char = %{
      char
      | meta: %{
          char.meta
          | inventory: new_inventory,
            vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 100}
        }
    }

    %{state | character: new_char, target: target}
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      "longxiang-gong" -> "龙象般若功"
      _ -> name
    end
  end
end

defmodule Kantele.Combat.Skills.FengleiZifa do
  @moduledoc """
  风雷子法（对照 `kungfu/skill/fenglei-zifa.c`）

  暗器载体：`valid_enable("throwing")`；
  `valid_force` 接受 基本暗器/风雷子法 共存。

  差异（TODO(migrate)）：
  - `she`（射日诀）需暗器、风雷子法>=100、neili>=100、目标存活且战斗中。
    内力对抗，成功造成 skill/2+random 技能伤害、扣暗器数量 1、busy 2。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fenglei-zifa"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "fenglei-zifa"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"she" => Kantele.Combat.Skills.FengleiZifa.She}
  end
end

defmodule Kantele.Combat.Skills.FengleiZifa.She do
  @moduledoc """
  射日诀「she」（对照 `kungfu/skill/fenglei-zifa/she.c`）

  门槛：暗器、风雷子法>=100、neili>=100、目标存活且战斗中。
  扣暗器数量 1、neili 80、busy 2。
  内力对抗，成功造成 skill/2+random 技能伤害。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fenglei-zifa"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "fenglei-zifa"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"she" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "fenglei-zifa/she",
      kind: :perform,
      gates: [
        {:custom, &gate_handing/1, "你现在手中并没有拿着暗器，无法施展出「射日诀」。\n"},
        {:custom, &gate_fighting/1, "「射日诀」只能在战斗中对对手使用。\n"},
        {:skill_min, "fenglei-zifa", 100, "你的风雷子法不够娴熟，无法施展「射日诀」。\n"},
        {:neili_min, 100, "你内力不足，无法施展「射日诀」。\n"},
        {:custom, &gate_target_alive/1, "对方都已经那些那些费力吧？\n"}
      ],
      costs: %{neili: 80},
      effects: [
        {:custom, &effect_she/1}
      ],
      busy: {:if_fighting, 2},
      message: fn ctx ->
        du = ctx.character.meta.inventory |> Enum.find(& &1.handing) || %{name: "暗器"}
        "$N身形微微一展，单手一晃，只听“飕”的一声，一#{du.meta.base_unit}#{du.name}如闪电般射向#{ctx.target.name}而去。\n"
      end
    }
  end

  defp gate_handing(ctx) do
    du = ctx.character.meta.inventory |> Enum.find(& &1.handing)

    if du && du.meta.amount && du.meta.amount >= 1 do
      :ok
    else
      {:error, "你现在手中并没有拿着暗器，无法施展出「射日诀」。\n"}
    end
  end

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能在战斗中对对手使用。\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?, do: :ok, else: {:error, "对方那些那些费力吧？\n"})

  defp effect_she(state) do
    char = state.character
    target = state.target
    du = char.meta.inventory |> Enum.find(& &1.handing)

    # 消耗暗器
    new_du =
      if du.meta.amount && du.meta.amount >= 1 do
        %{du | meta: %{du.meta | amount: du.meta.amount - 1}}
      else
        nil
      end

    new_inventory =
      Enum.map(char.meta.inventory, fn item ->
        if item == du,
          do:
            (if du.meta.amount && du.meta.amount >= 1 do
               %{du | meta: %{du.meta | amount: du.meta.amount - 1}}
             else
               nil
             end),
          else: item
      end)

    new_char = %{
      char
      | meta: %{
          char.meta
          | inventory: new_inventory,
            vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 80}
        }
    }

    skill = Stats.skill(new_char.meta.stats, "fenglei-zifa")
    my_exp = new_char.meta.stats.combat_exp + skill * skill / 10 * skill
    ob_exp = state.target.meta.stats.combat_exp

    success = :rand.uniform(my_exp) > ob_exp * 2 / 3

    if success do
      new_target = %{
        target
        | meta: %{
            target.meta
            | vitals: %{
                target.meta.vitals
                | qi: max(target.meta.vitals.qi - div(skill, 2) - :rand.uniform(div(skill, 2)), 0)
              }
          }
      }

      message =
        "#{"#{state.character.name}"}身形微微一展，单手一晃，只听“飕”的一声，一#{du.meta.base_unit}#{du.name}如闪电般射向#{
          target.name
        }而去。\n" <>
          "#{"#{target.name}"}闪避不及，顿时被这招打了个血肉模糊的窟窿，整个人疼得几乎都要散架。\n"
    else
      new_target = state.target

      message = "可是#{"#{state.target.name}"}轻轻一纵，躲闪开了#{"#{state.character.name}"}发出的#{du.name}。\n"
    end

    new_char = %{
      char
      | meta: %{
          char.meta
          | inventory:
              Enum.map(char.meta.inventory, fn item ->
                if item == du,
                  do:
                    (if du.meta.amount && du.meta.amount >= 1 do
                       %{du | meta: %{du.meta | amount: du.meta.amount - 1}}
                     else
                       nil
                     end),
                  else: item
              end),
            vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 80}
        }
    }

new_state = %{
      state
      | character: new_char
    }

    {new_target, message} =
      if success do
        new_target = %{
          target
          | meta: %{
              target.meta
              | vitals: %{
                  target.meta.vitals
                  | qi: max(target.meta.vitals.qi - div(skill, 2) - :rand.uniform(div(skill, 2)), 0)
                }
            }
        }

        message = "#{"#{state.character.name}"}身形微微一展，单手一晃，只听“飕”的一声，一#{du.meta.base_unit}#{du.name}如闪电般射向#{
          target.name
        }而去。\n" <>
                  "#{"#{target.name}"}闪避不及，顿时被这招打了个血肉模糊的窟窿，整个人疼得那些那些费力那些那些。\n"

        {new_target, message}
      else
        new_target = state.target

        message =
          "可是#{"#{state.target.name}"}轻轻一纵，躲闪开了#{"#{state.character.name}"}发出的#{du.name}。\n"

        {new_target, message}
      end

%{
      new_state
      | target: new_target,
        message: message
    }
  end
end

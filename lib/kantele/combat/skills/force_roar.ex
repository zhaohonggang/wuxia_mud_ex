defmodule Kantele.Combat.Skills.Force.Roar do
  @moduledoc """
  狮子吼/龙吟（对照 `kungfu/skill/force/roar.c`）

  仅限特定内功：龙象/天寰/混天/九阳/九阴/葵花/吸星/战神/易筋/混元；
  force>=180、neili>=800、非 no_fight/skybook 房间；
  扣 neili 800，busy 5。
  对房间内所有生物：con 对抗，失败者受精力伤害、可能昏迷。
  消息随内功类型不同（简化为统一消息）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @allowed_forces ~w(longxiang-gong tianhuan-shenjue huntian-qigong jiuyang-shengong
                     jiuyin-shengong kuihua-mogong xixing-dafa zhanshen-xinjing
                     yijinjing hunyuan-gong)

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
    %{"roar" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "force/roar",
      kind: :exert,
      gates: [
        {:custom, &gate_allowed_force/1, "你所学的内功中没有这种功能。\n"},
        {:custom, &gate_force_level/1, "你的内功修为不够。\n"},
        {:custom, &gate_room_ok/1, "在这里不能攻击他人。\n"},
        {:neili_min, 800, "你的真气不够。\n"}
      ],
      costs: %{neili: 800},
      effects: [
        {:custom, &effect_roar/1}
      ],
      busy: {:if_fighting, 5},
      message: fn ctx ->
        force = ctx.stats.mapped.force

        case force do
          "longxiang-gong" -> "$N运转真气，面无表情，歌声如梵唱般贯入众人耳中。\n"
          "huntian-qigong" -> "$N深深吸入一囗气，运足内力发出一阵长啸，音传百里，慑人心神。\n"
          "jiuyang-shengong" -> "$N仰天长啸，声音绵泊不绝，众人无不听得心驰神摇。\n"
          "jiuyin-shengong" -> "$N气凝丹田，猛然一声断喝，声音远远的传了开去，激荡不止。\n"
          "kuihua-mogong" -> "$N蓦地极嘶长呼，声音凄厉之极，令人毛骨悚然。\n"
          "yijinjing" -> "$N深深吸入一囗气，运起金刚禅狮子吼，发出惊天动地的一声巨吼。\n"
          "hunyuan-gong" -> "$N深深吸入一囗气，运起金刚禅狮子吼，发出惊天动地的一声巨吼。\n"
          _ -> "$N深深吸入一囗气，体内#{to_chinese(force)}真气急剧迸发，陡然一声巨啸。\n"
        end
      end
    }
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

  defp gate_allowed_force(ctx),
    do: if(ctx.stats.mapped.force in @allowed_forces, do: :ok, else: {:error, "你所学的内功中没有这种功能。\n"})

  defp gate_force_level(ctx),
    do: if(Stats.skill(ctx.stats, "force") >= 180, do: :ok, else: {:error, "你的内功修为不够。\n"})

  defp gate_room_ok(ctx),
    do: if(not (ctx.room.no_fight || ctx.room.skybook), do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp effect_roar(state) do
    char = state.character
    room_chars = state.room_chars || []
    skill = Stats.skill(char.meta.stats, "force")

    new_room_chars =
      Enum.map(room_chars, fn target ->
        if target == char or not target.meta.vitals.alive? do
          target
        else
          apply_roar_damage(target, skill)
        end
      end)

    %{state | room_chars: new_room_chars}
  end

  defp apply_roar_damage(target, skill) do
    con = target.meta.stats.con || 20

    if div(skill, 2) + :rand.uniform(div(skill, 2)) < con * 2 do
      target
    else
      max_neili = target.meta.vitals.max_neili
      damage = skill - div(max_neili, 10)

      if damage > 0 do
        new_jing = max(target.meta.vitals.jing - damage * 2, 0)
        new_eff_jing = max(target.meta.vitals.eff_jing - damage, 0)

        if target.meta.vitals.neili < skill * 2 do
          new_eff_jing = max(new_eff_jing - damage, 0)
        end

        if new_jing < 1 or new_eff_jing < 1 do
          %{
            target
            | meta: %{
                target.meta
                | vitals: %{target.meta.vitals | jing: 1, eff_jing: 1, unconscious: true}
              }
          }
        else
          %{
            target
            | meta: %{
                target.meta
                | vitals: %{target.meta.vitals | jing: new_jing, eff_jing: new_eff_jing}
              }
          }
        end
      else
        target
      end
    end
  end

  defp gate_allowed_force(ctx),
    do: if(ctx.stats.mapped.force in @allowed_forces, do: :ok, else: {:error, "你所学的内功中没有这种功能。\n"})

  defp gate_force_level(ctx),
    do: if(Stats.skill(ctx.stats, "force") >= 180, do: :ok, else: {:error, "你的内功修为不够。\n"})

  defp gate_room_ok(ctx),
    do: if(not (ctx.room.no_fight || ctx.room.skybook), do: :ok, else: {:error, "在这里不能攻击他人。\n"})
end

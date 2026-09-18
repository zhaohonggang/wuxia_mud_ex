defmodule Kantele.Combat.Skills.SankuShengong do
  @moduledoc """
  三苦神功（对照 `kungfu/skill/sanku-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，故恒真。

  差异（TODO(migrate)）：
  - `dispel`（排除异常）实现如下，可对自己/他人，清除所有 conditions。
  - `roar`（碧云神吼）实现如下，全房间攻击。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanku-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.SankuShengong.Powerup,
      "dispel" => Kantele.Combat.Skills.SankuShengong.Dispel,
      "roar" => Kantele.Combat.Skills.SankuShengong.Roar
    }
  end
end

defmodule Kantele.Combat.Skills.SankuShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/sanku-shengong/powerup.c`）

  取**基本 force** 等级：需 80 内力，耗 100；attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "sanku-shengong/powerup",
      gates: [
        {:neili_min, 80, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 3},
           defense: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的三苦神功运行完毕，将内力收回丹田。\n",
      message: "$N凝神息气，运起三苦神功的最高境界，只见一股轻烟缭绕周身。\n"
    }
end

defmodule Kantele.Combat.Skills.SankuShengong.Dispel do
  @moduledoc """
  排除异常「dispel」（对照 `kungfu/skill/sanku-shengong/dispel.c`）

  门槛：neili>=300（自身）/neili>=250（他人）。
  自身扣 neili 100，他人扣 250；清除目标所有 conditions。
  自身/他人 busy 不同。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanku-shengong"

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
    %{"dispel" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "sanku-shengong/dispel",
      kind: :exert,
      gates: [
        {:custom, &gate_self_or_target/1, ""},
        {:custom, &gate_neili/1, "你的内力不足，无法运满一个周天。\n"},
        {:custom, &gate_not_fighting_target/1, "对方正在打架，还是等他打完了再说吧。\n"},
        {:custom, &gate_not_busy_target/1, "对方现在正忙着呢，等他空了些再说吧。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_dispel/1}
      ],
      busy: 0,
      message: fn ctx ->
        if ctx.target == ctx.character do
          "$N深吸一口气，又缓缓的吐了出来。\n你默运#{to_chinese(ctx.stats.mapped.force)}，开始排除身体中的异常症状。\n"
        else
          "$N深吸一口气，将手掌粘到#{ctx.target.name}的背后。\n你默运#{to_chinese(ctx.stats.mapped.force)}，开始帮助#{
            ctx.target.name
          }排除身体中的异常症状。\n#{ctx.target.name}正在运功将你身体中的异常症状尽数排除。\n"
        end
      end
    }
  end

  defp gate_self_or_target(_ctx), do: :ok

  defp gate_neili(ctx) do
    cost = if ctx.target == ctx.character, do: 100, else: 250
    if ctx.character.meta.vitals.neili >= cost, do: :ok, else: {:error, "你的内力不足，无法运满一个周天。\n"}
  end

  defp gate_not_fighting_target(ctx) do
    if ctx.target == ctx.character || not ctx.target.meta.combat.busy > 0 ||
         Enum.empty?(ctx.target.meta.combat.enemies),
       do: :ok,
       else: {:error, "对方正在打架，还是等他打完了再说吧。\n"}
  end

  defp gate_not_busy_target(ctx) do
    if ctx.target == ctx.character || not ctx.target.meta.combat.busy > 0,
      do: :ok,
      else: {:error, "对方现在正忙着呢，等他空了些再说吧。\n"}
  end

  defp effect_dispel(state) do
    char = state.character
    target = state.target

    cost = if target == char, do: 100, else: 250
    new_vitals = %{char.meta.vitals | neili: char.meta.vitals.neili - cost}

    new_target =
      if target.meta.conditions && map_size(target.meta.conditions) > 0 do
        %{target | meta: %{target.meta | conditions: %{}}}
      else
        target
      end

    new_char = %{char | meta: %{char.meta | vitals: new_vitals}}

    state
    |> Map.put(:character, new_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, "你调息完毕，将内力收回丹田。\n")
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      _ -> name
    end
  end
end

defmodule Kantele.Combat.Skills.SankuShengong.Roar do
  @moduledoc """
  碧云神吼「roar」（对照 `kungfu/skill/sanku-shengong/roar.c`）

  门槛：neili>=500、skill>=50、非 no_fight 房间。
  扣 neili 150，受损 qi 10，busy 1。
  全房间遍历：con 对抗失败者受 jing 伤害、可能昏迷。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanku-shengong"

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
      id: "sanku-shengong/roar",
      kind: :exert,
      gates: [
        {:custom, &gate_no_fight/1, "这里不能攻击别人! \n"},
        {:custom, &gate_requirements/1, "你鼓足真气\"喵\"的吼了一声, 结果吓走了几只老鼠。\n"}
      ],
      costs: %{neili: 150, qi: 10},
      effects: [
        {:custom, &effect_roar/1}
      ],
      busy: 1,
      message: "$N深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼唐门无敌。\n"
    }
  end

  defp gate_no_fight(ctx), do: if(not ctx.room.no_fight, do: :ok, else: {:error, "这里不能攻击别人! \n"})

  defp gate_requirements(ctx) do
    if ctx.character.meta.vitals.neili >= 500 && Stats.skill(ctx.stats, "sanku-shengong") >= 50 do
      :ok
    else
      {:error, "你鼓足真气\"喵\"的吼了一声, 结果吓走了几只老鼠。\n"}
    end
  end

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

    message = "$N深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼唐门无敌。\n"

    state
    |> Map.put(:character, char)
    |> Map.put(:room_chars, new_room_chars)
    |> Map.put(:message, message)
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

        # Unconscious check
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
end

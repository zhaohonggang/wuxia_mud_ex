defmodule Kantele.Combat.Skills.FurongJinzhen do
  @moduledoc """
  芙蓉金针（对照 `kungfu/skill/furong-jinzhen.c`）

  暗器载体：`valid_enable("throwing")`；
  `valid_force` 接受 基本暗器/芙蓉金针 共存。

  差异（TODO(migrate)）：
  - `xian`（金针现影）需暗器、芙蓉金针>=80、force>=120、neili>=150、目标存活且战斗中。
    内力对抗，成功造成 ap/5+random 伤害。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "furong-jinzhen"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "furong-jinzhen"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"xian" => Kantele.Combat.Skills.FurongJinzhen.Xian}
  end
end

defmodule Kantele.Combat.Skills.FurongJinzhen.Xian do
  @moduledoc """
  金针现影「xian」（对照 `kungfu/skill/furong-jinzhen/xian.c`）

  门槛：暗器、芙蓉金针>=80、force>=120、neili>=150、目标存活且战斗中。
  扣暗器数量 1、neili 100、busy 2。
  内力对抗，成功造成 ap/5+random 伤害。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "furong-jinzhen"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "furong-jinzhen"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"xian" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "furong-jinzhen/xian",
      kind: :perform,
      gates: [
        {:custom, &gate_handing/1, "你现在手中并没有拿着暗器。\n"},
        {:custom, &gate_fighting/1, "「金针现影」只能在战斗中对对手使用。\n"},
        {:skill_min, "furong-jinzhen", 80, "你的芙蓉金针不够娴熟，难以施展「金针现影」。\n"},
        {:skill_min, "force", 120, "你的内功火候不够，难以施展「金针现影」。\n"},
        {:neili_min, 150, "你内力不够了。\n"},
        {:custom, &gate_target_alive/1, "对方那些那些费力吧？\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_xian/1}
      ],
      busy: {:if_fighting, 2},
      message: fn ctx ->
        du = ctx.character.meta.inventory |> Enum.find(& &1.handing)
        du_name = if du, do: du.name, else: "暗器"
        "只见#{"#{ctx.character.name}"}五指陡然箕张，#{"#{ctx.target.name}"}但觉眼前金光一闪，数股劲风随即扑面而来！\n"
      end
    }
  end

  defp gate_handing(ctx) do
    du = ctx.character.meta.inventory |> Enum.find(& &1.handing)
    if du && du.meta.skill_type == "throwing", do: :ok, else: {:error, "你现在手中并没有拿着暗器。\n"}
  end

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能在战斗中对对手使用。\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?, do: :ok, else: {:error, "对方那些那些费力吧？\n"})

  defp effect_xian(state) do
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
        if item == du, do: new_du, else: item
      end)

    skill = Stats.skill(char.meta.stats, "furong-jinzhen")
    ap = Stats.skill(char.meta.stats, "force") + Stats.skill(char.meta.stats, "throwing")
    dp = Stats.skill(target.meta.stats, "dodge") + Stats.skill(target.meta.stats, "parry")

success = div(ap, 2) + :rand.uniform(ap) > dp

    {new_target, message, damage} =
      if success do
        damage = div(skill, 5) + :rand.uniform(div(skill, 5))

        new_target = %{
          target
          | meta: %{
              target.meta
              | vitals: %{
                  target.meta.vitals
                  | qi: max(target.meta.vitals.qi - damage, 0)
              }
          }
        }

        message = "只见#{"#{char.name}"}五指陡然箕张，#{"#{target.name}"}但觉眼前金光一闪，数股劲风随即扑面而来！\n"

        {new_target, message, damage}
      else
        new_target = state.target

        message = "可是#{"#{target.name}"}早料得#{"#{char.name}"}有此一着，急忙飞身跃起，躲闪开来。\n"

        {new_target, message, 0}
      end

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
            vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 100}
        }
    }

    new_state = %{
      state
      | character: new_char
    }

    if success do
      new_target = %{
        target
        | meta: %{
            target.meta
            | vitals: %{
                target.meta.vitals
                | qi: max(target.meta.vitals.qi - damage, 0)
              }
          }
      }

      message = "只见#{"#{char.name}"}五指陡然箕张，#{"#{target.name}"}但觉眼前金光一闪，数股劲风随即扑面而来！\n"
    else
      new_target = target

      message = "可是#{"#{target.name}"}早料得#{"#{char.name}"}有此一着，急忙飞身跃起，躲闪开来。\n"
    end

    %{
      new_state
      | target: new_target,
        message: message
    }
  end
end

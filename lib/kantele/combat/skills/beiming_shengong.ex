defmodule Kantele.Combat.Skills.BeimingShengong do
  @moduledoc """
  北冥神功（对照 `kungfu/skill/beiming-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 逍遥心法/小无相/北冥神功 共存。

  差异（TODO(migrate)）：
  - `suck`（吸功）需空手、等级>=90、目标人类且战斗中、
    内功对抗成功扣目标 max_neili、增自身 max_neili，
    有冷却 temp "sucked"。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "beiming-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["xiaoyao-xinfa", "xiaowuxiang", "beiming-shengong"]

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
      "powerup" => Kantele.Combat.Skills.BeimingShengong.Powerup,
      "suck" => Kantele.Combat.Skills.BeimingShengong.Suck
    }
  end
end

defmodule Kantele.Combat.Skills.BeimingShengong.Suck do
  @moduledoc """
  吸功「suck」（对照 `kungfu/skill/beiming-shengong/suck.c`）

  门槛：北冥>=90、空手、非 no_fight、目标人类存活、
  自身 max_neili < current_neili_limit、目标 max_neili>=100、
  目标 max_neili >= 自身/5、目标非太玄功。
  内力对抗成功：扣目标 max_neili、增自身 max_neili（按差距递减）、
  双方 busy、设 temp "sucked" 冷却。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "beiming-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["xiaoyao-xinfa", "xiaowuxiang", "beiming-shengong"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"suck" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "beiming-shengong/suck",
      kind: :exert,
      gates: [
        {:custom, &gate_target_valid/1, "你要吸取谁的丹元？\n"},
        {:custom, &gate_no_fight/1, "在这里不能攻击他人。\n"},
        {:custom, &gate_empty_handed/1, "你必须空手才能施用北冥神功吸人丹元！\n"},
        {:custom, &gate_skill_level/1, "你的北冥神功功力不够，不能吸取对方的丹元！\n"},
        {:neili_min, 20, "你的内力不够，不能使用北冥神功。\n"},
        {:custom, &gate_can_absorb_more/1, "你的内功水平有限，再吸取也是徒劳。\n"},
        {:custom, &gate_target_has_neili/1, "目标丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"},
        {:custom, &gate_target_not_weak/1, "目标的内功修为远不如你，你无法从他体内吸取丹元！\n"},
        {:custom, &gate_not_taixuan/1, "目标运行太玄真气将吸功反弹回去。\n"},
        {:custom, &gate_not_cooldown/1, "你刚刚吸取过丹元！\n"}
      ],
      costs: %{neili: 10},
      effects: [
        {:custom, &effect_suck/1}
      ],
      busy: {:if_fighting, 4},
      message: "$N全身一振，伸出右手，轻轻握在$n的手臂上。\n"
    }
  end

  defp gate_target_valid(ctx) do
    if ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive? do
      :ok
    else
      {:error, "你要吸取谁的丹元？\n"}
    end
  end

  defp gate_no_fight(ctx), do: if(not ctx.room.no_fight, do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp gate_empty_handed(ctx) do
    if not ctx.character.meta.equipped.weapon, do: :ok, else: {:error, "你必须空手才能施用北冥神功吸人丹元！\n"}
  end

  defp gate_skill_level(ctx) do
    if Stats.skill(ctx.stats, "beiming-shengong") >= 90,
      do: :ok,
      else: {:error, "你的北冥神功功力不够，不能吸取对方的丹元！\n"}
  end

  defp gate_can_absorb_more(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    limit = ctx.character.meta.stats.max_neili_limit || my_max * 2
    if my_max < limit, do: :ok, else: {:error, "你的内功水平有限，再吸取也是徒劳。\n"}
  end

  defp gate_target_has_neili(ctx) do
    if ctx.target.meta.vitals.max_neili >= 100,
      do: :ok,
      else: {:error, "目标丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
  end

  defp gate_target_not_weak(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    tg_max = ctx.target.meta.vitals.max_neili
    if tg_max >= div(my_max, 5), do: :ok, else: {:error, "目标的内功修为远不如你，你无法从他体内吸取丹元！\n"}
  end

  defp gate_not_taixuan(ctx) do
    if ctx.target.meta.stats.mapped.force != "taixuan-gong",
      do: :ok,
      else: {:error, "目标运行太玄真气将吸功反弹回去。\n"}
  end

  defp gate_not_cooldown(ctx) do
    if not ctx.character.meta.combat.buffs |> Enum.any?(&(&1.key == "sucked")),
      do: :ok,
      else: {:error, "你刚刚吸取过丹元！\n"}
  end

  defp effect_suck(state) do
    char = state.character
    target = state.target

    sp = Stats.skill(char.meta.stats, "force")
    dp = Stats.skill(target.meta.stats, "force")

    success = sp + :rand.uniform(sp) > dp + :rand.uniform(dp)

    if success do
      beiming_lvl = Stats.skill(char.meta.stats, "beiming-shengong")
      sucked = 1 + div(beiming_lvl - 90, 10)
      sucked = max(sucked, 1)

      my_max = char.meta.vitals.max_neili
      tg_max = target.meta.vitals.max_neili

      sucked =
        cond do
          my_max > tg_max + 100 -> div(sucked, 2)
          my_max > tg_max + 200 -> div(sucked, 2)
          my_max > tg_max + 400 -> div(sucked, 2)
          my_max > tg_max + 800 -> div(sucked, 2)
          my_max > tg_max + 1600 -> div(sucked, 2)
          my_max > tg_max + 3200 -> div(sucked, 2)
          true -> sucked
        end

      if sucked < 1 do
        # No absorption
        new_char = %{char | meta: %{char.meta | combat: put_cooldown(char.meta.combat, "sucked")}}
        new_target = target
        message = "可是你发现对方内力似乎弱过你太多，一时难以吸收以为己用。\n"

        new_combat = put_busy(char.meta.combat, 4)
        new_char = %{char | meta: %{char.meta | combat: new_combat}}

        state
        |> Map.put(:character, new_char)
        |> Map.put(:target, new_target)
        |> Map.put(:message, message)
      else
        new_char_vitals = %{char.meta.vitals | max_neili: char.meta.vitals.max_neili + sucked}

        new_target_vitals = %{
          target.meta.vitals
          | max_neili: max(target.meta.vitals.max_neili - sucked, 0)
        }

        new_char = %{
          char
          | meta: %{
              char.meta
              | vitals: new_char_vitals,
                combat: put_cooldown(char.meta.combat, "sucked")
            }
        }

        new_target = %{
          target
          | meta: %{
              target.meta
              | vitals: new_target_vitals,
                combat: put_busy(target.meta.combat, 2)
            }
        }

        message = "你觉得#{target.name}的丹元自手掌源源不绝地流了进来。\n"

        new_combat = put_busy(char.meta.combat, 4)
        new_char = %{char | meta: %{char.meta | combat: new_combat}}

        state
        |> Map.put(:character, new_char)
        |> Map.put(:target, new_target)
        |> Map.put(:message, message)
      end
    else
      # Fail
      new_char = %{
        char
        | meta: %{char.meta | combat: put_cooldown(put_busy(char.meta.combat, 6), "sucked")}
      }

      new_target = target
      message = "可是#{target.name}看破了你的企图，机灵地溜了开去。\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, new_target)
      |> Map.put(:message, message)
    end
  end

  defp put_busy(combat, n), do: %{combat | busy: n}

  defp put_cooldown(combat, key),
    do: %{combat | buffs: combat.buffs ++ [%{key: key, applies: %{}, duration: 10}]}

  defp gate_target_valid(ctx),
    do:
      if(ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive?,
        do: :ok,
        else: {:error, "你要吸取谁的丹元？\n"}
      )

  defp gate_no_fight(ctx), do: if(not ctx.room.no_fight, do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp gate_empty_handed(ctx),
    do:
      if(not ctx.character.meta.equipped.weapon, do: :ok, else: {:error, "你必须空手才能施用北冥神功吸人丹元！\n"})

  defp gate_skill_level(ctx),
    do:
      if(Stats.skill(ctx.stats, "beiming-shengong") >= 90,
        do: :ok,
        else: {:error, "你的北冥神功功力不够，不能吸取对方的丹元！\n"}
      )

  defp gate_can_absorb_more(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    limit = ctx.character.meta.stats.max_neili_limit || my_max * 2
    if my_max < limit, do: :ok, else: {:error, "你的内功水平有限，再吸取也是徒劳。\n"}
  end

  defp gate_target_has_neili(ctx),
    do:
      if(ctx.target.meta.vitals.max_neili >= 100,
        do: :ok,
        else: {:error, "目标丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
      )

  defp gate_target_not_weak(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    tg_max = ctx.target.meta.vitals.max_neili
    if tg_max >= div(my_max, 5), do: :ok, else: {:error, "目标的内功修为远不如你，你无法从他体内吸取丹元！\n"}
  end

  defp gate_not_taixuan(ctx),
    do:
      if(ctx.target.meta.stats.mapped.force != "taixuan-gong",
        do: :ok,
        else: {:error, "目标运行太玄真气将吸功反弹回去。\n"}
      )

  defp gate_not_cooldown(ctx),
    do:
      if(not ctx.character.meta.combat.buffs |> Enum.any?(&(&1.key == "sucked")),
        do: :ok,
        else: {:error, "你刚刚吸取过丹元！\n"}
      )
end

defmodule Kantele.Combat.Skills.BeimingShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/beiming-shengong/powerup.c`）

  需 100 内力，耗 100；attack=defense=北冥/3，持续 北冥 秒；
  战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "beiming-shengong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够!\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "beiming-shengong"}, 3},
           defense: {:div, {:skill, "beiming-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "beiming-shengong"},
      expire_message: "你的北冥神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起北冥神功，全身真气澎湃，衣衫随之鼓胀。\n"
    }
end

defmodule Kantele.Combat.Skills.XixingDafa do
  @moduledoc """
  吸星大法（对照 `kungfu/skill/xixing-dafa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili`/`can_learn` 前置未实现。
  - `valid_damage` 被动（吸化对方内力）未接入。
  - `suck`（吸功）实现如下，含目标 max_neili 扣减与自身 max_neili 增加。
  - `sangong`（散功）实现如下，扣除自身 max_neili。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xixing-dafa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你试着按照法门运转了一下内息，忽然觉得心火如焚，丹田却是一阵冰凉！\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功修为不足，难以修炼吸星大法。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)或从运用(exert)中增加熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.XixingDafa.Powerup,
      "suck" => Kantele.Combat.Skills.XixingDafa.Suck,
      "sangong" => Kantele.Combat.Skills.XixingDafa.Sangong
    }
  end
end

defmodule Kantele.Combat.Skills.XixingDafa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xixing-dafa/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=吸星/3，持续 吸星 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xixing-dafa/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xixing-dafa"}, 3},
           defense: {:div, {:skill, "xixing-dafa"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "xixing-dafa"},
      expire_message: "你的吸星大法运行完毕，将内力收回丹田。\n",
      message: "$N深深呼入一口气，缓缓吐出，顿时全身真气蒸腾，被罡劲所笼罩。\n"
    }
end

defmodule Kantele.Combat.Skills.XixingDafa.Suck do
  @moduledoc """
  吸功「suck」（对照 `kungfu/skill/xixing-dafa/suck.c`）

  门槛：吸星>=200、非 no_fight、目标人类存活且战斗中、
  自身 max_neili < current_neili_limit、目标 max_neili>=100、
  目标 max_neili >= 自身/5、目标非太玄功、目标非空手/武器。
  内力对抗：sp=force vs dp=target force。
  成功：扣目标 max_neili = 1 + (吸星-120)/10，增自身 max_neili 同量、
  增 exception/xixing-count，双方 busy、扣 neili 10。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xixing-dafa"

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
    %{"suck" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "xixing-dafa/suck",
      kind: :exert,
      gates: [
        {:custom, &gate_target_valid/1, "你只能吸取战斗中的对手的丹元！\n"},
        {:custom, &gate_no_fight/1, "在这里不能攻击他人。\n"},
        {:custom, &gate_skill_level/1, "你的吸星大法尚未大成，还不能吸取对方的丹元收为己用！\n"},
        {:neili_min, 100, "你的内力不够，不能使用吸星大法。\n"},
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
      busy: 0,
      message: fn ctx ->
        if ctx.character.meta.equipped.weapon do
          "$N把手中的#{ctx.character.meta.equipped.weapon.name}一扬，慢慢的逼向#{ctx.target.name}，#{
            ctx.target.name
          }连忙架住。\n"
        else
          "$N探出右手，平平的拍在#{ctx.target.name}的胸前，似乎没有半点力道。\n"
        end
      end
    }
  end

  defp gate_target_valid(ctx) do
    if ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive? &&
         ctx.target.meta.combat.busy > 0 do
      :ok
    else
      {:error, "你只能吸取战斗中的对手的丹元！\n"}
    end
  end

  defp gate_no_fight(ctx), do: if(not ctx.room.no_fight, do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp gate_skill_level(ctx) do
    if Stats.skill(ctx.stats, "xixing-dafa") >= 200,
      do: :ok,
      else: {:error, "你的吸星大法尚未大成，还不能吸取对方的丹元收为己用！\n"}
  end

  defp gate_can_absorb_more(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    limit = ctx.character.meta.stats.max_neili_limit || my_max * 2
    if my_max < limit, do: :ok, else: {:error, "你的内功水平有限，再吸取也是徒劳。\n"}
  end

  defp gate_target_has_neili(ctx) do
    if ctx.target.meta.vitals.max_neili >= 100,
      do: :ok,
      else: {:error, ctx.target.name <> "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
  end

  defp gate_target_not_weak(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    tg_max = ctx.target.meta.vitals.max_neili

    if tg_max >= div(my_max, 5),
      do: :ok,
      else: {:error, ctx.target.name <> "的内功修为远不如你，你无法从他体内吸取丹元！\n"}
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

    success = sp + :rand.uniform(sp) > dp + :rand.uniform(dp) || not target.meta.vitals.alive?

    if success do
      lvl = Stats.skill(char.meta.stats, "xixing-dafa")
      amount = 1 + div(lvl - 120, 10)
      amount = max(amount, 1)

      new_char_vitals = %{char.meta.vitals | max_neili: char.meta.vitals.max_neili + amount}

      new_target_vitals = %{
        target.meta.vitals
        | max_neili: max(target.meta.vitals.max_neili - amount, 0)
      }

      new_char = %{
        char
        | meta: %{
            char.meta
            | vitals: new_char_vitals,
              combat: put_busy(char.meta.combat, 4 + :rand.uniform(4))
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

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, new_target)
      |> Map.put(:message, message)
    else
      new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 7)}}
      message = "可是#{target.name}看破了你的企图，运用内力震开了你，随即躲了开去。\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, target)
      |> Map.put(:message, message)
    end
  end

  defp put_busy(combat, n), do: %{combat | busy: n}

  defp gate_target_valid(ctx) do
    if ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive? &&
         ctx.target.meta.combat.busy > 0 do
      :ok
    else
      {:error, "你只能吸取战斗中的对手的丹元！\n"}
    end
  end

  defp gate_no_fight(ctx), do: if(not ctx.room.no_fight, do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp gate_skill_level(ctx),
    do:
      if(Stats.skill(ctx.stats, "xixing-dafa") >= 200,
        do: :ok,
        else: {:error, "你的吸星大法尚未大成，还不能吸取对方的丹元收为己用！\n"}
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
        else: {:error, ctx.target.name <> "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
      )

  defp gate_target_not_weak(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    tg_max = ctx.target.meta.vitals.max_neili

    if tg_max >= div(my_max, 5),
      do: :ok,
      else: {:error, ctx.target.name <> "的内功修为远不如你，你无法从他体内吸取丹元！\n"}
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

defmodule Kantele.Combat.Skills.XixingDafa.Sangong do
  @moduledoc """
  散功「sangong」（对照 `kungfu/skill/xixing-dafa/sangong.c`）

  门槛：max_neili >= 1。
  扣 max_neili 1，busy 1。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xixing-dafa"

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
    %{"sangong" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "xixing-dafa/sangong",
      kind: :exert,
      gates: [
        {:max_neili_min, 1, "你已经将内力散尽，没什么必要再散功了。\n"},
        {:custom, &gate_self_only/1, "你只能用吸星大法为自己散功。\n"}
      ],
      costs: %{},
      effects: [
        {:custom, &effect_sangong/1}
      ],
      busy: 1,
      message: "你默默的按照吸星大法的诀窍将内力散入奇经八脉。\n"
    }
  end

  defp gate_self_only(ctx),
    do: if(ctx.target == ctx.character, do: :ok, else: {:error, "你只能用吸星大法为自己散功。\n"})

  defp effect_sangong(state) do
    char = state.character
    new_vitals = %{char.meta.vitals | max_neili: max(char.meta.vitals.max_neili - 1, 0)}
    new_char = %{char | meta: %{char.meta | vitals: new_vitals}}
    state |> Map.put(:character, new_char) |> Map.put(:message, "你默默的按照吸星大法的诀窍将内力散入奇经八脉。\n")
  end

  defp gate_self_only(_ctx), do: :ok
end

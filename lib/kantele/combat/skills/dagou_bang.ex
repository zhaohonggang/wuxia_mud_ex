defmodule Kantele.Combat.Skills.DagouBang do
  @moduledoc """
  打狗棒法（对照 `kungfu/skill/dagou-bang.c`）

  杖法载体：`valid_enable("staff")`、`valid_enable("parry")`；
  `valid_force` 接受 蛤蟆功/混元一气/九阴真经 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别/性格限制未实现。
  - `chan`（缠字诀）需杖、打狗棒法>=60、force>=100、neili>=100、目标存活且战斗中、目标非busy。
  - `feng`（封字诀）需杖、打狗棒法>=180、force>=180、neili>=200、目标存活且战斗中。
  - `tian`（天下无狗）需杖、打狗棒法>=220、force>=300、neili>=500、目标存活且战斗中。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dagou-bang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_force(force), do: force in ["hamagong", "hunyuan-yiqi", "jiuyin-zhenjing"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.DagouBang.Chan,
      "feng" => Kantele.Combat.Skills.DagouBang.Feng,
      "tian" => Kantele.Combat.Skills.DagouBang.Tian
    }
  end
end

defmodule Kantele.Combat.Skills.DagouBang.Chan do
  @moduledoc """
  缠字诀「chan」（对照 `kungfu/skill/dagou-bang/chan.c`）

  门槛：杖、打狗棒法>=60、force>=100、neili>=100、目标存活且战斗中、目标非busy。
  杖法/2+random 对抗目标闪避，成功使目标 busy (level/18+2)、自身 busy 1、扣 neili 50。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dagou-bang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_force(force), do: force in ["hamagong", "hunyuan-yiqi", "jiuyin-zhenjing"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"chan" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "dagou-bang/chan",
      kind: :perform,
      gates: [
        {:custom, &gate_staff/1, "你使用的武器不对，难以施展「缠字诀」。\n"},
        {:custom, &gate_fighting/1, "「缠字诀」只能对战斗中的对手使用。\n"},
        {:custom, &gate_target_not_busy/1, "目标目前正自顾不暇，放胆攻击吧。\n"},
        {:skill_min, "dagou-bang", 60, "你打狗棒法不够娴熟，难以施展「缠字诀」。\n"},
        {:skill_min, "force", 100, "你的内功火候不足，难以施展「缠字诀」。\n"},
        {:neili_min, 100, "你现在的真气不够，难以施展「缠字诀」。\n"},
        {:custom, &gate_target_alive/1, "对方都已经这样了，用不着这么费力吧？\n"}
      ],
      costs: %{neili: 50},
      effects: [
        {:custom, &effect_chan/1}
      ],
      busy: 0,
      message: "$N使出打狗棒法「缠」字诀，棒头在地下连点，连绵不绝地挑向$n的小腿和脚踝。\n"
    }
  end

  defp gate_staff(ctx) do
    if ctx.character.meta.equipped.weapon &&
         ctx.character.meta.equipped.weapon.meta.skill_type == "staff" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展「缠字诀」。\n"}
    end
  end

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能对战斗中的对手使用。\n"}
      )

  defp gate_target_not_busy(ctx),
    do:
      if(not ctx.target.meta.combat.busy > 0,
        do: :ok,
        else: {:error, ctx.target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
      )

  defp gate_target_alive(ctx),
    do:
      if(ctx.target && ctx.target.meta.vitals.alive?,
        do: :ok,
        else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
      )

defp effect_chan(state) do
    char = state.character
    target = state.target

    level = Stats.skill(char.meta.stats, "dagou-bang")
    dp = Stats.skill(target.meta.stats, "dodge")

    success = div(level, 2) + :rand.uniform(level) > dp

    {new_target, new_char, message} =
      if success do
        new_target = %{
          target
          | meta: %{target.meta | combat: put_busy(target.meta.combat, div(level, 18) + 2)}
        }

        new_char = %{
          char
          | meta: %{
              char.meta
              | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 50},
                combat: put_busy(char.meta.combat, 1)
            }
        }

        message = "棒影窜动间#{"#{target.name}"}招式陡然一紧，已被#{"#{char.name}"}攻的蹦跳不停，手忙脚乱！\n"

        {new_target, new_char, message}
      else
        new_target = target
        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 2)}}
        message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，镇定解招，一丝不乱。\n"

        {new_target, new_char, message}
      end

    final_char = %{
      new_char
      | meta: %{
          new_char.meta
          | vitals: %{new_char.meta.vitals | neili: new_char.meta.vitals.neili - 50}
      }
    }

    state
    |> Map.put(:character, final_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp put_busy(combat, n), do: %{combat | busy: n}

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能对战斗中的对手使用。\n"}
      )

  defp gate_target_not_busy(ctx),
    do:
      if(not ctx.target.meta.combat.busy > 0,
        do: :ok,
        else: {:error, ctx.target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
      )

  defp gate_target_alive(ctx),
    do:
      if(ctx.target && ctx.target.meta.vitals.alive?,
        do: :ok,
        else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
      )
end

defmodule Kantele.Combat.Skills.DagouBang.Feng do
  @moduledoc """
  封字诀「feng」（对照 `kungfu/skill/dagou-bang/feng.c`）

  门槛：杖、打狗棒法>=180、force>=180、neili>=200、目标存活且战斗中。
  杖法/2+random 对抗目标闪避，成功使目标 busy (skill/20+2)、自身 busy 1、扣 neili 100。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dagou-bang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_force(force), do: force in ["hamagong", "hunyuan-yiqi", "jiuyin-zhenjing"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"feng" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "dagou-bang/feng",
      kind: :perform,
      gates: [
        {:custom, &gate_staff/1, "你使用的武器不对，难以施展「封字诀」。\n"},
        {:custom, &gate_fighting/1, "只能对战斗中的对手使用。\n"},
        {:skill_min, "dagou-bang", 180, "你打狗棒法不够娴熟，难以施展「封字诀」。\n"},
        {:skill_min, "force", 180, "你的内功火候不够，难以施展「封字诀」。\n"},
        {:neili_min, 200, "你现在的真气不够，难以施展「封字诀」。\n"},
        {:custom, &gate_target_alive/1, "对方都已经这样了，用不着这么费力吧？\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_feng/1}
      ],
      busy: 0,
      message: "$N使出打狗棒法「封」字诀，棒风如涛，逼向$n！\n"
    }
  end

  defp gate_staff(ctx) do
    if ctx.character.meta.equipped.weapon &&
         ctx.character.meta.equipped.weapon.meta.skill_type == "staff" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展「封字诀」。\n"}
    end
  end

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能对战斗中的对手使用。\n"}
      )

  defp gate_target_alive(ctx),
    do:
      if(ctx.target && ctx.target.meta.vitals.alive?,
        do: :ok,
        else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
      )

  defp effect_feng(state) do
    char = state.character
    target = state.target

    level = Stats.skill(char.meta.stats, "dagou-bang")
    dp = Stats.skill(target.meta.stats, "dodge")

    success = div(level, 2) + :rand.uniform(level) > dp

    {new_target, new_char, message} =
      if success do
        new_target = %{
          target
          | meta: %{target.meta | combat: put_busy(target.meta.combat, div(level, 20) + 2)}
        }

        new_char = %{
          char
          | meta: %{
              char.meta
              | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 100},
                combat: put_busy(char.meta.combat, 1)
            }
        }

        message = "棒风如涛，逼向#{"#{target.name}"}！\n"

        {new_target, new_char, message}
      else
        new_target = target
        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 2)}}
        message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，镇定解招，一丝不乱。\n"

        {new_target, new_char, message}
      end

    state
    |> Map.put(:character, new_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp put_busy(combat, n), do: %{combat | busy: n}
end

defmodule Kantele.Combat.Skills.DagouBang.Tian do
  @moduledoc """
  天下无狗「tian」（对照 `kungfu/skill/dagou-bang/tian.c`）

  门槛：杖、打狗棒法>=220、force>=300、neili>=500、目标存活且战斗中。
  杖法对抗目标闪避，成功造成伤害、自身 busy 1。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dagou-bang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  @impl true
  def valid_force(force), do: force in ["hamagong", "hunyuan-yiqi", "jiuyin-zhenjing"]

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"tian" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "dagou-bang/tian",
      kind: :perform,
      gates: [
        {:custom, &gate_staff/1, "你使用的武器不对，难以施展「天下无狗」。\n"},
        {:custom, &gate_fighting/1, "只能对战斗中的对手使用。\n"},
        {:skill_min, "dagou-bang", 220, "你打狗棒法不够娴熟，难以施展「天下无狗」。\n"},
        {:skill_min, "force", 300, "你的内功火候不够，难以施展「天下无狗」。\n"},
        {:neili_min, 500, "你现在的真气不够，难以施展「天下无狗」。\n"},
        {:custom, &gate_target_alive/1, "对方都已经这样了，用不着这么费力吧？\n"}
      ],
      costs: %{neili: 500},
      effects: [
        {:custom, &effect_tian/1}
      ],
      busy: 0,
      message: "$N使出打狗棒法「天」字诀，棒影如山，势不可挡！\n"
    }
  end

  defp gate_staff(ctx) do
    if ctx.character.meta.equipped.weapon &&
         ctx.character.meta.equipped.weapon.meta.skill_type == "staff" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展「天下无狗」。\n"}
    end
  end

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能对战斗中的对手使用。\n"}
      )

  defp gate_target_alive(ctx),
    do:
      if(ctx.target && ctx.target.meta.vitals.alive?,
        do: :ok,
        else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
      )

  defp effect_tian(state) do
    char = state.character
    target = state.target

    level = Stats.skill(char.meta.stats, "dagou-bang")
    dp = Stats.skill(target.meta.stats, "dodge")

    success = level + :rand.uniform(level) > dp

    {new_target, new_char, message} =
      if success do
        damage = div(level, 2) + :rand.uniform(div(level, 2))

        new_target = %{
          target
          | meta: %{
              target.meta
              | vitals: %{target.meta.vitals | qi: max(target.meta.vitals.qi - damage, 0)}
          }
        }

        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 1)}}
        message = "棒影如山，#{"#{target.name}"}难以招架！\n"

        {new_target, new_char, message}
      else
        new_target = target
        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 2)}}
        message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，一跃而开！\n"

        {new_target, new_char, message}
      end

    state
    |> Map.put(:character, new_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp put_busy(combat, n), do: %{combat | busy: n}
end

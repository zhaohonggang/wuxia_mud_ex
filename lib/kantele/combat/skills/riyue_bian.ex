defmodule Kantele.Combat.Skills.RiyueBian do
  @moduledoc """
  日月鞭法（对照 `kungfu/skill/riyue-bian.c`）

  鞭法载体：`valid_enable("whip")`、`valid_enable("parry")`；
  `valid_force` 接受 日月心法/日月鞭法 共存。

  差异（TODO(migrate)）：
  - `chan`（缠绕）需鞭、neili>=80、目标存活且战斗中、目标非busy、需激发日月鞭法。
  - `he`（合字诀）需鞭、neili>=350、目标存活且战斗中。
  - `shang`（上字诀）需鞭、neili>=100、目标存活且战斗中。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @allowed_forces ~w(riyue-xinfa riyue-bian)

  @impl true
  def id(), do: "riyue-bian"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_force(force), do: force in @allowed_forces

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
      "chan" => Kantele.Combat.Skills.RiyueBian.Chan,
      "he" => Kantele.Combat.Skills.RiyueBian.He,
      "shang" => Kantele.Combat.Skills.RiyueBian.Shang
    }
  end
end

defmodule Kantele.Combat.Skills.RiyueBian.Chan do
  @moduledoc """
  缠绕「chan」（对照 `kungfu/skill/riyue-bian/chan.c`）

  门槛：鞭、neili>=80、目标存活且战斗中、目标非busy、需激发日月鞭法。
  鞭法/2+random 对抗目标招架，成功使目标 busy (skill/20+2)、自身 busy 1。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "riyue-bian"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_force(force), do: force in @allowed_forces

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
      id: "riyue-bian/chan",
      kind: :perform,
      gates: [
        {:custom, &gate_whip/1, "你没有拿着鞭子。\n"},
        {:custom, &gate_fighting/1, "牵制攻击只能对战斗中的对手使用。\n"},
        {:custom, &gate_target_not_busy/1, "目标目前正自顾不暇，放胆攻击吧！\n"},
        {:neili_min, 80, "你的内力不够。\n"},
        {:custom, &gate_mapped/1, "你没有激发日月鞭法，无法施展「缠绕」诀！\n"},
        {:custom, &gate_target_alive/1, "对方那些那些费力吧？\n"}
      ],
      costs: %{neili: 0},
      effects: [
        {:custom, &effect_chan/1}
      ],
      busy: 0,
      message: "$N使出日月鞭法「缠绕」诀，连挥数鞭企图把$n的全身缠绕起来。\n"
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

  defp gate_whip(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "whip", do: :ok, else: {:error, "你没有拿着鞭子。\n"}
  end

  defp gate_fighting(ctx),
    do: if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
      do: :ok,
      else: {:error, "在这里不能攻击他人。\n"}
    )

  defp gate_target_not_busy(ctx),
    do: if(not ctx.target.meta.combat.busy > 0,
      do: :ok,
      else: {:error, ctx.target.name <> "目前正自顾不暇，放胆攻击吧！\n"}
    )

  defp gate_mapped(ctx),
    do:
      if(ctx.character.meta.stats.mapped.whip == "riyue-bian",
        do: :ok,
        else: {:error, "你没有激发日月鞭法，无法施展「缠绕」诀！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?,
      do: :ok,
      else: {:error, "对方那些那些费力吧？\n"}
    )

  defp effect_chan(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "whip")
    dp = Stats.skill(target.meta.stats, "parry")

    success = div(ap, 2) + :rand.uniform(ap) > dp

    {new_target, new_char, message} =
      if success do
        skill = Stats.skill(char.meta.stats, "riyue-bian")
        new_target = %{
          target
          | meta: %{target.meta | combat: put_busy(target.meta.combat, div(skill, 20) + 2)}
        }

        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 1)}}
        message = "结果#{"#{target.name}"}被#{"#{char.name}"}攻了个措手不及！\n"

        {new_target, new_char, message}
      else
        new_target = target
        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 2)}}
        message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，小心应对，那些那些费力那些那些。\n"

        {new_target, new_char, message}
      end

    state
    |> Map.put(:character, new_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp gate_whip(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "whip", do: :ok, else: {:error, "你没有拿着鞭子。\n"}
  end

  defp gate_fighting(ctx),
    do: if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
      do: :ok,
      else: {:error, "在这里不能攻击他人。\n"}
    )

  defp gate_target_not_busy(ctx),
    do:
      if(not ctx.target.meta.combat.busy > 0,
        do: :ok,
        else: {:error, ctx.target.name <> "目前正自顾不暇，放胆攻击吧！\n"}
      )

  defp gate_mapped(ctx),
    do:
      if(ctx.character.meta.stats.mapped.whip == "riyue-bian",
        do: :ok,
        else: {:error, "你没有激发日月鞭法，无法施展「缠绕」诀！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?,
      do: :ok,
      else: {:error, "对方那些那些费力吧？\n"}
    )

  defp put_busy(combat, n), do: %{combat | busy: n}
end

defmodule Kantele.Combat.Skills.RiyueBian.He do
  @moduledoc """
  合字诀「he」（对照 `kungfu/skill/riyue-bian/he.c`）

  门槛：鞭、neili>=350、目标存活且战斗中。
  鞭法/2+random 对抗目标招架，成功使目标 busy (skill/15+2)、自身 busy 1。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "riyue-bian"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_force(force), do: force in @allowed_forces

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"he" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "riyue-bian/he",
      kind: :perform,
      gates: [
        {:custom, &gate_whip/1, "你没有拿着鞭子。\n"},
        {:custom, &gate_fighting/1, "牵制攻击只能对战斗中的对手使用。\n"},
        {:neili_min, 350, "你现在真气不够，无法施展「合字诀」！\n"},
        {:custom, &gate_mapped/1, "你没有激发日月鞭法，无法施展「合字诀」！\n"},
        {:custom, &gate_target_alive/1, "对方那些那些费力吧？\n"}
      ],
      costs: %{neili: 0},
      effects: [
        {:custom, &effect_he/1}
      ],
      busy: 0,
      message: "$N使出日月鞭法「合」字诀，鞭影如梭，企图将$n全身缠绕。\n"
    }
  end

  defp gate_whip(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "whip", do: :ok, else: {:error, "你没有拿着鞭子。\n"}
  end

  defp gate_fighting(ctx),
    do: if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
      do: :ok,
      else: {:error, "在这里不能攻击他人。\n"}
    )

  defp gate_mapped(ctx),
    do:
      if(ctx.character.meta.stats.mapped.whip == "riyue-bian",
        do: :ok,
        else: {:error, "你没有激发日月鞭法，无法施展「合字诀」！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?,
      do: :ok,
      else: {:error, "对方那些那些费力吧？\n"}
    )

  defp effect_he(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "whip")
    dp = Stats.skill(target.meta.stats, "parry")

    success = div(ap, 2) + :rand.uniform(ap) > dp

    {new_target, new_char, message} =
      if success do
        skill = Stats.skill(char.meta.stats, "riyue-bian")
        new_target = %{
          target
          | meta: %{target.meta | combat: put_busy(target.meta.combat, div(skill, 15) + 2)}
        }

        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 1)}}
        message = "结果#{"#{target.name}"}被#{"#{char.name}"}攻了个措手不及！\n"

        {new_target, new_char, message}
      else
        new_target = target
        new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 2)}}
        message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，小心应对，那些那些费力那些那些。\n"

        {new_target, new_char, message}
      end

    state
    |> Map.put(:character, new_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp gate_whip(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "whip", do: :ok, else: {:error, "你没有拿着鞭子。\n"}
  end

  defp gate_fighting(ctx),
    do: if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
      do: :ok,
      else: {:error, "在这里不能攻击他人。\n"}
    )

  defp gate_mapped(ctx),
    do:
      if(ctx.character.meta.stats.mapped.whip == "riyue-bian",
        do: :ok,
        else: {:error, "你没有激发日月鞭法，无法施展「合字诀」！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?,
      do: :ok,
      else: {:error, "对方那些那些费力吧？\n"}
    )

  defp put_busy(combat, n), do: %{combat | busy: n}
end

defmodule Kantele.Combat.Skills.RiyueBian.Shang do
  @moduledoc """
  上字诀「shang」（对照 `kungfu/skill/riyue-bian/shang.c`）

  门槛：鞭、neili>=100、目标存活且战斗中。
  鞭法/2+random 对抗目标闪避，成功造成伤害。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "riyue-bian"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_force(force), do: force in @allowed_forces

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"shang" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "riyue-bian/shang",
      kind: :perform,
      gates: [
        {:custom, &gate_whip/1, "你没有拿着鞭子。\n"},
        {:custom, &gate_fighting/1, "牵制攻击只能对战斗中的对手使用。\n"},
        {:neili_min, 100, "你现在真气不够，无法施展「上字诀」！\n"},
        {:custom, &gate_mapped/1, "你没有激发日月鞭法，无法施展「上字诀」！\n"},
        {:custom, &gate_target_alive/1, "对方那些那些费力吧？\n"}
      ],
      costs: %{neili: 0},
      effects: [
        {:custom, &effect_shang/1}
      ],
      busy: 0,
      message: "$N使出日月鞭法「上」字诀，鞭影如梭，势若奔雷！\n"
    }
  end

  defp gate_whip(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "whip", do: :ok, else: {:error, "你没有拿着鞭子。\n"}
  end

  defp gate_fighting(ctx),
    do: if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
      do: :ok,
      else: {:error, "在这里不能攻击他人。\n"}
    )

  defp gate_mapped(ctx),
    do:
      if(ctx.character.meta.stats.mapped.whip == "riyue-bian",
        do: :ok,
        else: {:error, "你没有激发日月鞭法，无法施展「上字诀」！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?,
      do: :ok,
      else: {:error, "对方那些那些费力吧？\n"}
    )

  defp effect_shang(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "whip")
    dp = Stats.skill(target.meta.stats, "dodge")

    success = div(ap, 2) + :rand.uniform(ap) > dp

    {new_target, message} =
      if success do
        new_target = %{
          target
          | meta: %{
              target.meta
              | vitals: %{
                  target.meta.vitals
                  | qi: max(target.meta.vitals.qi - 50, 0)
              }
          }
        }

        message = "鞭影如梭，#{"#{target.name}"}躲闪不及！\n"

        {new_target, message}
      else
        new_target = target
        message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，小心应对，那些那些费力那些那些。\n"

        {new_target, message}
      end

    state
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp gate_whip(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "whip", do: :ok, else: {:error, "你没有拿着鞭子。\n"}
  end

  defp gate_fighting(ctx),
    do: if(not ctx.character.meta.combat.busy > 0 || Enum.empty?(ctx.character.meta.combat.enemies),
      do: :ok,
      else: {:error, "在这里不能攻击他人。\n"}
    )

  defp gate_mapped(ctx),
    do:
      if(ctx.character.meta.stats.mapped.whip == "riyue-bian",
        do: :ok,
        else: {:error, "你没有激发日月鞭法，无法施展「上字诀」！\n"}
      )

  defp gate_target_alive(ctx),
    do: if(ctx.target && ctx.target.meta.vitals.alive?,
      do: :ok,
      else: {:error, "对方那些那些费力吧？\n"}
    )
end
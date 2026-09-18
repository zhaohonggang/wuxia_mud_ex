defmodule Kantele.Combat.Skills.BingxinJue do
  @moduledoc """
  冰心诀（对照 `kungfu/skill/bingxin-jue.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真（未声明）。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别判定误用 `query("bingxin-jue",1)`（永不触发），未实装。
  - `freeze`（寒气）实现如下，需 skill>=150、neili>=1000、目标存活、在战斗中。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bingxin-jue"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你的先天根骨孱弱，无法修炼冰心诀。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候不足，不能学冰心诀。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.BingxinJue.Powerup,
      "freeze" => Kantele.Combat.Skills.BingxinJue.Freeze
    }
  end
end

defmodule Kantele.Combat.Skills.BingxinJue.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/bingxin-jue/powerup.c`）

  需 300 内力，耗 100；临时提升 attack=defense=冰心/3，持续 冰心 秒；
  战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "bingxin-jue/powerup",
      gates: [
        {:neili_min, 300, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "bingxin-jue"}, 3},
           defense: {:div, {:skill, "bingxin-jue"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "bingxin-jue"},
      expire_message: "你的冰心诀运行完毕，将内力收回丹田。\n",
      message: "$N双掌一合，冰心诀真气激荡，周身白雾缭绕，寒气逼人。\n"
    }
end

defmodule Kantele.Combat.Skills.BingxinJue.Freeze do
  @moduledoc """
  寒气「freeze」（对照 `kungfu/skill/bingxin-jue/freeze.c`）

  门槛：冰心>=150、neili>=1000、目标存活、在战斗中。
  ap=force, dp=force 对抗；成功：damage=force/3+random(force/3)，扣目标 qi/劲 qi、
  扣目标 neili = damage（若目标 neili > damage），busy 1。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "bingxin-jue"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的基本内功火候不足，不能学冰心诀。\n"}
    else
      :ok
    end
  end

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"freeze" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "bingxin-jue/freeze",
      kind: :exert,
      gates: [
        {:custom, &gate_target_valid/1, "你只能用寒气攻击战斗中的对手。\n"},
        {:skill_min, "bingxin-jue", 150, "你的冰心决火候不够，无法运用寒气。\n"},
        {:neili_min, 1000, "你的内力不够!\n"},
        {:custom, &gate_target_alive/1, "对方都已经这样了，用不着这么费力吧？\n"}
      ],
      costs: %{neili: 0},
      effects: [
        {:custom, &effect_freeze/1}
      ],
      busy: 2,
      message: "$N默运冰心决，一股寒气迎面扑向$n，四周登时雪花飘飘。\n"
    }
  end

  defp gate_target_alive(ctx) do
    if ctx.target && ctx.target.meta.vitals.alive? do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp gate_target_valid(ctx) do
    if ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive? &&
         ctx.character.meta.combat.busy > 0 &&
         ctx.target.meta.combat.busy > 0 do
      :ok
    else
      {:error, "你只能用寒气攻击战斗中的对手。\n"}
    end
  end

  defp effect_freeze(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "force")
    dp = Stats.skill(char.meta.stats, "force")

    success = div(ap, 2) + :rand.uniform(ap) > :rand.uniform(dp)

    {new_target, msg_suffix} =
      if success do
        damage = div(ap, 3) + :rand.uniform(div(ap, 3))

        new_t_q = max(target.meta.vitals.qi - damage, 0)
        new_t_eff_q = max(target.meta.vitals.eff_qi - damage, 0)

        new_t_neili =
          if target.meta.vitals.neili > damage,
            do: target.meta.vitals.neili - damage,
            else: 0

        new_target = %{
          target
          | meta: %{
              target.meta
              | vitals: %{
                  target.meta.vitals
                  | qi: new_t_q,
                    eff_qi: new_t_eff_q,
                    neili: new_t_neili
                },
                combat: put_busy(target.meta.combat, 1)
            }
        }

        {new_target, "你觉得#{target.name}的全身功力如融雪般消失得无影无踪！\n"}
      else
        {target, "你感到一阵寒意自心底泛起，连忙运动抵抗，堪勘无事。\n"}
      end

    message = "$N默运冰心决，一股寒气迎面扑向$n，四周登时雪花飘飘。\n" <> msg_suffix

    state
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp put_busy(combat, n), do: %{combat | busy: n}

  defp gate_target_valid(ctx) do
    if ctx.target && ctx.target != ctx.character &&
         ctx.target.meta.vitals.alive? &&
         ctx.character.meta.combat.busy > 0 &&
         ctx.target.meta.combat.busy > 0 do
      :ok
    else
      {:error, "你只能用寒气攻击战斗中的对手。\n"}
    end
  end
end

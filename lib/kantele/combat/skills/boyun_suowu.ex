defmodule Kantele.Combat.Skills.BoyunSuowu do
  @moduledoc """
  拨云锁雾（对照 `kungfu/skill/boyun-suowu.c`）

  拳脚载体：`valid_enable("hand")`、`valid_enable("dodge")`、`valid_enable("parry")`；
  仅可学不可练。`valid_force` 接受 碧云心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别限制未实现。
  - `dian`（云雾暗点）需空手、手法>=100、碧云心法>=100、neili>=800；
    手法+敏捷对抗目标闪避，成功使目标 busy、扣 neili 500。
  - `meng`（回梦）需空手、拨云锁雾>=140、碧云心法>=130、neili>=300；
    手法对抗目标内功，成功扣目标 qi/wound、扣 neili 300、busy 2。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "boyun-suowu"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "dodge", "parry"]

  @impl true
  def valid_force(force), do: force == "biyun-xinfa"

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
      "dian" => Kantele.Combat.Skills.BoyunSuowu.Dian,
      "meng" => Kantele.Combat.Skills.BoyunSuowu.Meng
    }
  end
end

defmodule Kantele.Combat.Skills.BoyunSuowu.Dian do
  @moduledoc """
  云雾暗点「dian」（对照 `kungfu/skill/boyun-suowu/dian.c`）

  门槛：空手、拨云锁雾>=100、碧云心法>=100、neili>=800、目标存活且战斗中。
  手法+敏捷*10 对抗目标闪避+敏捷*10，成功使目标 busy (ap/100+2)、扣 neili 500。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "boyun-suowu"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "dodge", "parry"]

  @impl true
  def valid_force(force), do: force == "biyun-xinfa"

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"dian" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "boyun-suowu/dian",
      kind: :perform,
      gates: [
        {:custom, &gate_empty_handed/1, "你只能空手使用「云雾暗点」。\n"},
        {:custom, &gate_fighting/1, "只能对战斗中的对手使用。\n"},
        {:skill_min, "boyun-suowu", 100, "你的「拨云锁雾」不够娴熟，不能使用「云雾暗点」。\n"},
        {:skill_min, "biyun-xinfa", 100, "你的碧云心法不够熟练！\n"},
        {:neili_min, 800, "你的内力不够。\n"},
        {:custom, &gate_target_alive/1, "对方都已经这样了，用不着这么费力吧？\n"}
      ],
      costs: %{neili: 500},
      effects: [
        {:custom, &effect_dian/1}
      ],
      busy: 0,
      message: "$N手腕一翻，信手一个拈花诀，内力暗吐，“嗤”的一声，破空而去！\n"
    }
  end

  defp gate_empty_handed(ctx),
    do: if(not ctx.character.meta.equipped.weapon, do: :ok, else: {:error, "你只能空手使用「云雾暗点」。\n"})

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

  defp effect_dian(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "hand") + char.meta.stats.dex * 10
    dp = Stats.skill(target.meta.stats, "dodge") + target.meta.stats.dex * 10

    success = div(ap, 2) + :rand.uniform(ap) > dp

    {new_target, new_char, message} =
      if success do
        new_target = %{
          target
          | meta: %{target.meta | combat: put_busy(target.meta.combat, div(ap, 100) + 2)}
        }

        new_char = %{
          char
          | meta: %{char.meta | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 500}}
        }

        message = "你觉得#{"#{target.name}"}全身顿觉一麻，似乎不能动弹。\n"

        {new_target, new_char, message}
      else
        new_target = target

        new_char = %{
          char
          | meta: %{char.meta | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 500}}
        }

        message = "只见#{"#{target.name}"}侧身一让，一阵风声，破空而过！\n"

        {new_target, new_char, message}
      end

    state
    |> Map.put(:character, new_char)
    |> Map.put(:target, new_target)
    |> Map.put(:message, message)
  end

  defp put_busy(combat, n), do: %{combat | busy: n}
end

defmodule Kantele.Combat.Skills.BoyunSuowu.Meng do
  @moduledoc """
  回梦「meng」（对照 `kungfu/skill/boyun-suowu/meng.c`）

  门槛：空手、拨云锁雾>=140、碧云心法>=130、neili>=300、目标存活且战斗中。
  手法对抗目标内功，成功扣目标 qi/wound、扣 neili 300、busy 2。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "boyun-suowu"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "dodge", "parry"]

  @impl true
  def valid_force(force), do: force == "biyun-xinfa"

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"meng" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "boyun-suowu/meng",
      kind: :perform,
      gates: [
        {:custom, &gate_empty_handed/1, "你必须空手才能使用「回梦」！\n"},
        {:custom, &gate_fighting/1, "「回梦」只能对战斗中的对手使用。\n"},
        {:skill_min, "boyun-suowu", 140, "你的拨云锁雾不够娴熟，不会使用「回梦」。\n"},
        {:skill_min, "biyun-xinfa", 130, "你的碧云心法不够高，不能用来反震伤敌。\n"},
        {:neili_min, 300, "你现在内力太弱，不能使用「回梦」。\n"},
        {:custom, &gate_target_alive/1, "对方都已经这样了，用不着这么费力吧？\n"}
      ],
      costs: %{neili: 300},
      effects: [
        {:custom, &effect_meng/1}
      ],
      busy: 0,
      message: "$N默念口诀，使出「拨云锁雾」之「回梦」，意欲以内力震晕$n。\n"
    }
  end

  defp gate_empty_handed(ctx),
    do: if(not ctx.character.meta.equipped.weapon, do: :ok, else: {:error, "你必须空手才能使用「回梦」！\n"})

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

  defp effect_meng(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "hand")
    dp = Stats.skill(target.meta.stats, "force")

    success = div(ap, 2) + :rand.uniform(ap) > dp

    if success do
      damage = div(ap * 3, 5)

      new_t_q = max(target.meta.vitals.qi - damage, 0)
      new_t_wq = max(target.meta.vitals.eff_qi - div(damage, 2), 0)

      new_target = %{
        target
        | meta: %{
            target.meta
            | vitals: %{
                target.meta.vitals
                | qi: new_t_q,
                  eff_qi: new_t_wq
              },
              combat: put_busy(target.meta.combat, 2)
          }
      }

      new_char = %{
        char
        | meta: %{
            char.meta
            | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 300},
              combat: put_busy(char.meta.combat, 2)
          }
      }

      message =
        case damage do
          d when d < 20 -> "结果#{"#{target.name}"}受到#{"#{char.name}"}的内力反震，闷哼一声，看上去很是疲惫。\n"
          d when d < 40 -> "结果#{"#{target.name}"}被#{"#{char.name}"}以内力反震，只觉得胸中烦闷，只想好好休息休息。\n"
          d when d < 80 -> "结果#{"#{target.name}"}被#{"#{char.name}"}以内力一震，脑中嗡嗡作响，意识开始模糊起来！\n"
          _ -> "结果#{"#{target.name}"}被#{"#{char.name}"}的内力一震，眼前一黑，向后便倒，眼看就要不醒人事了！\n"
        end

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, new_target)
      |> Map.put(:message, message)
    else
      new_char = %{char | meta: %{char.meta | combat: put_busy(char.meta.combat, 3)}}
      message = "可是#{"#{target.name}"}看破了#{"#{char.name}"}的企图，并没有上当。\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, target)
      |> Map.put(:message, message)
    end
  end

  defp put_busy(combat, n), do: %{combat | busy: n}
end

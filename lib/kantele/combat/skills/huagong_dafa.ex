defmodule Kantele.Combat.Skills.HuagongDafa do
  @moduledoc """
  化功大法（对照 `kungfu/skill/huagong-dafa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 龟息功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili`/毒技门槛未实现。
  - `valid_damage` 被动（化功毒效 + freezing 状态）未接入。
  - `hua`（吸功）实现如下，含目标 max_neili 扣减与自身 busy。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huagong-dafa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "guixi-gong"

  @impl true
  def valid_learn(stats) do
    cond do
      stats.con < 30 ->
        {:error, "你试着运转了一下内力，登时觉得胸闷难耐！\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的基本内功火候不足，不能学化功大法。\n"}

      Stats.skill(stats, "poison") < 120 ->
        {:error, "你的基本毒技火候不足，不能学化功大法。\n"}

      Stats.skill(stats, "poison") < Stats.skill(stats, id()) ->
        {:error, "你的基本毒技水平有限，不能领会更高深的化功大法。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, id()) ->
        {:error, "你的基本内功水平有限，不能领会更高深的化功大法。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)或练毒的来增加熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.HuagongDafa.Powerup,
      "hua" => Kantele.Combat.Skills.HuagongDafa.Hua
    }
  end
end

defmodule Kantele.Combat.Skills.HuagongDafa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/huagong-dafa/powerup.c`）

  需 100 内力，耗 100；临时提升 attack=dodge=化功/3，持续 化功 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "huagong-dafa/powerup",
      gates: [
        {:neili_min, 100, "你的真气不够！"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "huagong-dafa"}, 3},
           dodge: {:div, {:skill, "huagong-dafa"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "huagong-dafa"},
      expire_message: "你的化功大法运行完毕，将内力收回丹田。\n",
      message: "$N脸色一青，充满了煞气，周身泛起萤萤绿光，诡秘异常！\n"
    }
end

defmodule Kantele.Combat.Skills.HuagongDafa.Hua do
  @moduledoc """
  吸功「hua」（对照 `kungfu/skill/huagong-dafa/hua.c`）

  门槛：化功>=100、空手、非 no_fight、目标人类存活、
  自身 neili>=120、目标 neili>=10 且 max_neili>=10、
  目标 max_neili <= 自身 max_neili * 4/3、目标非太玄功。
  内力对抗：sp=force+dodge vs dp=target force+dodge。
  成功：扣目标 max_neili = random(4) + (化功-90)/8，增自身 max_neili 同量（未实现增，仅扣目标）；
  双方 busy、扣 neili 100。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "huagong-dafa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "guixi-gong"

  @impl true
  def valid_learn(_stats), do: :ok

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"hua" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "huagong-dafa/hua",
      kind: :exert,
      gates: [
        {:custom, &gate_target_valid/1, "你要化谁的内力？\n"},
        {:custom, &gate_no_fight/1, "在这里不能攻击他人。\n"},
        {:custom, &gate_not_busy/1, "你现在正忙，无法化他人内力。\n"},
        {:custom, &gate_empty_handed/1, "你必须空手才能施用化功大法！\n"},
        {:custom, &gate_skill_level/1, "你的化功大法功力不够，不能施展！\n"},
        {:neili_min, 120, "你的内力不够，不能施展化功大法。\n"},
        {:custom, &gate_target_has_neili/1, "目标已然内力涣散，不必再化了。\n"},
        {:custom, &gate_target_not_stronger/1, "目标的内功修为远胜于你，你无法化他的内力！\n"},
        {:custom, &gate_not_taixuan/1, "目标运行太玄真气将吸功反弹回去。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_hua/1}
      ],
      busy: 0,
      message: "$N全身骨节爆响，双臂暴长数尺，手掌刷的一抖，粘向$n！\n"
    }
  end

  defp gate_target_valid(ctx) do
    if ctx.target && ctx.target != ctx.character && ctx.target.meta.vitals.alive? do
      :ok
    else
      {:error, "你要化谁的内力？\n"}
    end
  end

  defp gate_no_fight(ctx), do: if(not ctx.room.no_fight, do: :ok, else: {:error, "在这里不能攻击他人。\n"})

  defp gate_not_busy(ctx) do
    if not ctx.character.meta.combat.busy > 0, do: :ok, else: {:error, "你现在正忙，无法化他人内力。\n"}
  end

  defp gate_empty_handed(ctx) do
    if not ctx.character.meta.equipped.weapon, do: :ok, else: {:error, "你必须空手才能施用化功大法！\n"}
  end

  defp gate_skill_level(ctx) do
    if Stats.skill(ctx.stats, "huagong-dafa") >= 100,
      do: :ok,
      else: {:error, "你的化功大法功力不够，不能施展！\n"}
  end

  defp gate_target_has_neili(ctx) do
    if ctx.target.meta.vitals.neili >= 10 && ctx.target.meta.vitals.max_neili >= 10 do
      :ok
    else
      {:error, ctx.target.name <> "已然内力涣散，不必再化了。\n"}
    end
  end

  defp gate_target_not_stronger(ctx) do
    my_max = ctx.character.meta.vitals.max_neili
    tg_max = ctx.target.meta.vitals.max_neili

    if tg_max <= my_max * 4 / 3,
      do: :ok,
      else: {:error, ctx.target.name <> "的内功修为远胜于你，你无法化他的内力！\n"}
  end

  defp gate_not_taixuan(ctx) do
    if ctx.target.meta.stats.mapped.force != "taixuan-gong",
      do: :ok,
      else: {:error, "目标运行太玄真气将吸功反弹回去。\n"}
  end

  defp effect_hua(state) do
    char = state.character
    target = state.target

    sp = Stats.skill(char.meta.stats, "force") + Stats.skill(char.meta.stats, "dodge")
    dp = Stats.skill(target.meta.stats, "force") + Stats.skill(target.meta.stats, "dodge")

    success = div(sp, 2) + :rand.uniform(sp) > :rand.uniform(dp) || not target.meta.vitals.alive?

    if success do
      lvl = Stats.skill(char.meta.stats, "huagong-dafa")
      amount = :rand.uniform(4) + div(lvl - 90, 8)
      amount = max(amount, 1)

      new_tg_max = max(target.meta.vitals.max_neili - amount, 0)

      new_target = %{
        target
        | meta: %{
            target.meta
            | vitals: %{target.meta.vitals | max_neili: new_tg_max},
              combat: put_busy(target.meta.combat, 2)
          }
      }

      new_char = %{
        char
        | meta: %{char.meta | combat: put_busy(char.meta.combat, 2 + :rand.uniform(2))}
      }

      message = "你觉得#{target.name}的丹元自手掌源源不绝地流了进来。\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, new_target)
      |> Map.put(:message, message)
    else
      new_char = %{
        char
        | meta: %{char.meta | combat: put_busy(char.meta.combat, 2 + :rand.uniform(3))}
      }

      message = "可是#{target.name}看破了你的企图，内力猛地一震，借势溜了开去。\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, target)
      |> Map.put(:message, message)
    end
  end

  defp put_busy(combat, n), do: %{combat | busy: n}
end

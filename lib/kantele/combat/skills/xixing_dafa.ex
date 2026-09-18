defmodule Kantele.Combat.Skills.XixingDafa do
  @moduledoc """
  吸星大法（对照 `kungfu/skill/xixing-dafa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格（光明磊落）判定、`can_learn/xixing-dafa/ren`
    修习前置、以及 `max_neili`/`exception/xixing-count` 相关检查未实现。
  - `valid_damage` 被动（吸化对方内力）未接入。
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
    %{"powerup" => Kantele.Combat.Skills.XixingDafa.Powerup}
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

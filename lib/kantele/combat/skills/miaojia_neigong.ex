defmodule Kantele.Combat.Skills.MiaojiaNeigong do
  @moduledoc """
  苗家内功（对照 `kungfu/skill/miaojia-neigong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性 & 等级 > 49」性别限制按 `meta.env[:gender]` 实装；
    引擎无 LPC `::valid_learn` 的父类附加检查（如 `can_learn` 系列），此层未迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "miaojia-neigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats, character) do
    if gender_of(character) == "无性" and Stats.skill(stats, id()) > 49 do
      {:error, "你无根无性，阴阳不调，难以领会高深的苗家内功。\n"}
    else
      :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.MiaojiaNeigong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.MiaojiaNeigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/miaojia-neigong/powerup.c`）

  耗 100 内力，临时提升 attack=defense=苗家/3，持续 苗家 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "miaojia-neigong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够了。"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "miaojia-neigong"}, 3},
           defense: {:div, {:skill, "miaojia-neigong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "miaojia-neigong"},
      expire_message: "你的苗家内功运行完毕，将内力收回丹田。\n",
      message: "$N运起苗家内功，气劲迸发，全身上下便犹如蒙上了一层淡淡的金纸。\n"
    }
end

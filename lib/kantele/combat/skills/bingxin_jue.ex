defmodule Kantele.Combat.Skills.BingxinJue do
  @moduledoc """
  冰心决（对照 `kungfu/skill/bingxin-jue.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 无条件（可任意内功共存）。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别判定误用 `query("bingxin-jue", 1)`（应为
    `query_skill`），实际永不触发，故未实装。
  - `query_neili_improve` 成长公式未接入。
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
      stats.int < 26 -> {:error, "你觉得冰心决深奥无比，一时难以领会。\n"}
      Stats.skill(stats, "force") < 100 -> {:error, "你的基本内功火候还不够，还不能学习冰心决。\n"}
      true -> :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.BingxinJue.Powerup}
  end
end

defmodule Kantele.Combat.Skills.BingxinJue.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/bingxin-jue/powerup.c`）

  取**基本 force** 等级：需 300 内力，耗 100；临时提升
  attack=defense=基本内功/3，持续 基本内功 秒；战斗中 busy 3 轮。
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
           attack: {:div, {:skill, "force"}, 3},
           defense: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的冰心决运行完毕，将内力收回丹田。\n",
      message: "$N默运冰心决，全身关节一阵爆响，一股至阴的内劲从浑身经脉迸发出来。\n"
    }
end

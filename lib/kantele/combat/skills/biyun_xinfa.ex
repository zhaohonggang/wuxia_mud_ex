defmodule Kantele.Combat.Skills.BiyunXinfa do
  @moduledoc """
  碧云心法（对照 `kungfu/skill/biyun-xinfa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "biyun-xinfa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 40 do
      {:error, "你的基本内功太差了。\n"}
    else
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
    %{"powerup" => Kantele.Combat.Skills.BiyunXinfa.Powerup}
  end
end

defmodule Kantele.Combat.Skills.BiyunXinfa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/biyun-xinfa/powerup.c`）

  取**基本 force** 等级：需 80 内力，耗 100；attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "biyun-xinfa/powerup",
      gates: [
        {:neili_min, 80, "你的内力不够。\n"},
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
      expire_message: "你的碧云心法运行完毕，将内力收回丹田。\n",
      message: "$N凝神息气，运起碧云心法的最高境界，只见一股轻烟缭绕周身。\n"
    }
end

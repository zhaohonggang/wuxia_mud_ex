defmodule Kantele.Combat.Skills.SankuShengong do
  @moduledoc """
  三苦神功（对照 `kungfu/skill/sanku-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，故恒真。

  差异（TODO(migrate)）：
  - `dispel` 清除异常状态（可对自己/他人，消耗 neili 100/250），涉及 target-side 逻辑，
    标记为差异项手写。
  - `roar`（碧云神吼）为范围攻击扰乱技，涉及全房间遍历与伤害结算，标记为差异项手写。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sanku-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.SankuShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.SankuShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/sanku-shengong/powerup.c`）

  取**基本 force** 等级：需 80 内力，耗 100；attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "sanku-shengong/powerup",
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
      expire_message: "你的三苦神功运行完毕，将内力收回丹田。\n",
      message: "$N凝神息气，运起三苦神功的最高境界，只见一股轻烟缭绕周身。\n"
    }
end

defmodule Kantele.Combat.Skills.XuehaiMogong do
  @moduledoc """
  血海魔功（对照 `kungfu/skill/xuehai-mogong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 密宗内功 共存。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xuehai-mogong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "mizong-neigong"

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.XuehaiMogong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.XuehaiMogong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xuehai-mogong/powerup.c`）

  取**基本 force** 等级：需 150 内力，耗 100；临时提升 attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xuehai-mogong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
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
      expire_message: "你的血海魔功运行完毕，将内力收回丹田。\n",
      message: "$N仰天一声长哮，提运血海魔功，全身骨骼爆响，真气荡漾，衣衫顿时膨胀，气势迫人。\n"
    }
end

defmodule Kantele.Combat.Skills.LiangyiShengong do
  @moduledoc """
  两仪神功（对照 `kungfu/skill/liangyi-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 昆仑心法/自身 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "liangyi-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["kunlun-xinfa", "liangyi-shengong"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 60 do
      {:error, "你的基本内功火候还不够。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.LiangyiShengong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.LiangyiShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/liangyi-shengong/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=两仪/3，持续 两仪 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "liangyi-shengong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "liangyi-shengong"}, 3},
           defense: {:div, {:skill, "liangyi-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "liangyi-shengong"},
      expire_message: "你的两仪神功运行完毕，将内力收回丹田。\n",
      message: "$N陡然一声清啸，运起两仪神功，全身骨骼一阵爆响，真气荡漾，衣衫顿时膨胀，气势迫人。\n"
    }
end

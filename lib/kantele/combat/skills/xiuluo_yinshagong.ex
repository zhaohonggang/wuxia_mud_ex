defmodule Kantele.Combat.Skills.XiuluoYinshagong do
  @moduledoc """
  修罗阴煞功（对照 `kungfu/skill/xiuluo-yinshagong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 五毒心法/蛤蟆功/瞬息千里 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xiuluo-yinshagong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["wudu-xinfa", "hamagong", "shunxi-qianli"]

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
    %{"powerup" => Kantele.Combat.Skills.XiuluoYinshagong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.XiuluoYinshagong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xiuluo-yinshagong/powerup.c`）

  需 100 内力，耗 100；临时提升 attack=defense=修罗/3，持续 修罗 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xiuluo-yinshagong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xiuluo-yinshagong"}, 3},
           defense: {:div, {:skill, "xiuluo-yinshagong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "xiuluo-yinshagong"},
      expire_message: "你的修罗阴煞功运行完毕，将内力收回丹田。\n",
      message: "$N运起修罗阴煞功，头顶黑气蒸腾，全身肌肤坟起黑色的鳞甲，双目凶光四射！\n"
    }
end

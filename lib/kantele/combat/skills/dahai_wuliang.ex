defmodule Kantele.Combat.Skills.DahaiWuliang do
  @moduledoc """
  大海无量（对照 `kungfu/skill/dahai-wuliang.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 无量心法/灵鹫心法/八荒六合唯我独尊功/五斗米神功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "dahai-wuliang"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["wuliang-xinfa", "lingjiu-xinfa", "bahuang-gong", "wudoumi-shengong"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 50 do
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
    %{"powerup" => Kantele.Combat.Skills.DahaiWuliang.Powerup}
  end
end

defmodule Kantele.Combat.Skills.DahaiWuliang.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/dahai-wuliang/powerup.c`）

  取**基本 force** 等级：耗 100 内力，临时提升 attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "dahai-wuliang/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够了。"},
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
      expire_message: "你的大海无量运行完毕，将内力收回丹田。\n",
      message: "$N运起大海无量神功，一股气流至体内迸发而出，衣衫束巾随即鼓胀飘起。\n"
    }
end

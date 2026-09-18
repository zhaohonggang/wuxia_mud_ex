defmodule Kantele.Combat.Skills.NeiBagua do
  @moduledoc """
  内八卦（对照 `kungfu/skill/nei-bagua.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 自身/八卦心法/商贾内功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "nei-bagua"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["nei-bagua", "bagua-xinfa", "shangjia-neigong"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 80 ->
        {:error, "你的基本内功火候还不够。\n"}

      Stats.skill(stats, "wai-bagua") < 100 ->
        {:error, "你的外八卦功夫火候还不够。\n"}

      true ->
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
    %{"powerup" => Kantele.Combat.Skills.NeiBagua.Powerup}
  end
end

defmodule Kantele.Combat.Skills.NeiBagua.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/nei-bagua/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=内八卦/3、parry=内八卦/6，
  持续 内八卦 秒；战斗中 busy 1..3 轮。

  注：LPC 的 remove_effect 传 `skill` 后按 /3、/6 分别回收，等价于本引擎
  按各加成原值精确回收。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "nei-bagua/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "nei-bagua"}, 3},
           defense: {:div, {:skill, "nei-bagua"}, 3},
           parry: {:div, {:skill, "nei-bagua"}, 6}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "nei-bagua"},
      expire_message: "你的内八卦神功运行完毕，将内力收回丹田。\n",
      message: "$N凝神聚气，运起内八卦神功，真气顿时灌满全身，衣衫欲裂，气势磅礴。\n"
    }
end

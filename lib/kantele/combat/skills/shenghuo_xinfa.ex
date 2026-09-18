defmodule Kantele.Combat.Skills.ShenghuoXinfa do
  @moduledoc """
  圣火心法（对照 `kungfu/skill/shenghuo-xinfa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 圣火神功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "shenghuo-xinfa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "shenghuo-shengong"

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 10 do
      {:error, "你的基本内功火候还不够，还不能学习圣火心法。\n"}
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
    %{"powerup" => Kantele.Combat.Skills.ShenghuoXinfa.Powerup}
  end
end

defmodule Kantele.Combat.Skills.ShenghuoXinfa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/shenghuo-xinfa/powerup.c`）

  取**基本 force** 等级：需 150 内力，耗 150；临时提升
  attack=dodge=parry=基本内功/6，持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "shenghuo-xinfa/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 150},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 6},
           dodge: {:div, {:skill, "force"}, 6},
           parry: {:div, {:skill, "force"}, 6}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的圣火心法运行完毕，长长地吐了口气，将内力收回丹田。\n",
      message: "$N默运圣火心法，脸色先由黄翻紫，紧接着由紫翻蓝，再由蓝翻红，最后又恢复为黄色，甚为诡异。\n"
    }
end

defmodule Kantele.Combat.Skills.ShenlongXinfa do
  @moduledoc """
  神龙心法（对照 `kungfu/skill/shenlong-xinfa.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 蛇岛内功 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "shenlong-xinfa"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force == "shedao-neigong"

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)或从运用(exert)中增加熟练度（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.ShenlongXinfa.Powerup}
  end
end

defmodule Kantele.Combat.Skills.ShenlongXinfa.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/shenlong-xinfa/powerup.c`）

  取**基本 force** 等级：耗 100 内力，临时提升 attack=dodge=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "shenlong-xinfa/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够!"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 3},
           dodge: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的神龙心法运行完毕，将内力收回丹田。\n",
      message: "$N舌尖一咬，喷出一口紫血，顿时一股内力直贯双臂！\n"
    }
end

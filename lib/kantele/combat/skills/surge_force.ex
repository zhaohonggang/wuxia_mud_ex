defmodule Kantele.Combat.Skills.SurgeForce do
  @moduledoc """
  怒海狂涛（对照 `kungfu/skill/surge-force.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC `valid_force` 恒真。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别（必须男性）限制未实现（本模型暂无性别字段）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "surge-force"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的基本内功火候还不够，还不能修炼怒海狂涛。\n"}

      stats.str < 45 ->
        {:error, "你的膂力不足，难以修习怒海狂涛。\n"}

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
    %{"powerup" => Kantele.Combat.Skills.SurgeForce.Powerup}
  end
end

defmodule Kantele.Combat.Skills.SurgeForce.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/surge-force/powerup.c`）

  需 500 内力，耗 200；临时提升 attack=defense=怒海*2/5、unarmed_damage=怒海/5，
  持续 怒海 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "surge-force/powerup",
      gates: [
        {:neili_min, 500, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 200},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:mul, {:skill, "surge-force"}, 2}, 5},
           defense: {:div, {:mul, {:skill, "surge-force"}, 2}, 5},
           unarmed_damage: {:div, {:skill, "surge-force"}, 5}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "surge-force"},
      expire_message: "你的怒海狂涛运行完毕，将内力收回丹田。\n",
      message: "$N一声长啸，激起一阵狂风，气浪翻翻滚滚，向两旁散开。\n霎时之间，便似长风动起，气云聚合，天地渺然，有如海浪滔滔。\n"
    }
end

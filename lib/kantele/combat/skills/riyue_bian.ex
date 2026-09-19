defmodule Kantele.Combat.Skills.RiyueBian do
  @moduledoc """
  日月鞭法（对照 `kungfu/skill/riyue-bian.c`）

  鞭法载体：`valid_enable("whip")`、`valid_enable("parry")`；
  `valid_force` 接受 日月心法/日月鞭法 共存。

  绝招：`perform_list/0` 提供 缠绕「chan」、合字诀「he」、伤字诀「shang」。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的属性/int/con/max_neili/force/whip 门槛未实现。
  - LPC `practice_skill` 可练（qi/neili 消耗）；本引擎 practice_cost 返回 nil（只能学）。
  - 三个绝招的 `living(target)` 检查、chan 的目标 busy 先行拒绝 等目标侧门内断言
    视目标进程不可读而省略；he 的逐次 `do_attack` 折算为一次合计伤害（见模块文档）。
  """

  use Kantele.Combat.Skill

  @allowed_forces ~w(riyue-xinfa riyue-bian)

  @impl true
  def id(), do: "riyue-bian"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @impl true
  def valid_force(force), do: force in @allowed_forces

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.RiyueBian.Chan,
      "he" => Kantele.Combat.Skills.Performs.RiyueBian.He,
      "shang" => Kantele.Combat.Skills.Performs.RiyueBian.Shang
    }
  end
end
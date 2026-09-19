defmodule Kantele.Combat.Skills.BoyunSuowu do
  @moduledoc """
  拨云锁雾（对照 `kungfu/skill/boyun-suowu.c`）

  拳脚载体：`valid_enable("hand")`、`valid_enable("dodge")`、`valid_enable("parry")`；
  仅可学不可练。`valid_force` 接受 碧云心法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/boyun_suowu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的空手/碧云心法/max_neili 门槛未实现（`valid_learn` 恒 :ok）。
  - LPC `practice_skill` 训练（qi 25 消耗）未建模（`practice_cost` 返回 nil）。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "boyun-suowu"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "dodge", "parry"]

  @impl true
  def valid_force(force), do: force == "biyun-xinfa"

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
      "dian" => Kantele.Combat.Skills.Performs.BoyunSuowu.Dian,
      "meng" => Kantele.Combat.Skills.Performs.BoyunSuowu.Meng
    }
  end
end
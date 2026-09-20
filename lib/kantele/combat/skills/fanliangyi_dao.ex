defmodule Kantele.Combat.Skills.FanliangyiDao do
  @moduledoc """
  反两仪刀法（对照 `kungfu/skill/fanliangyi-dao.c`）

  刀法载体：`valid_enable("blade")` / `valid_enable("parry")`；
  LPC 的 `valid_enable("array")` 用法本引擎未建模（TODO(migrate)），
  组阵功能经「双剑和壁」绝招（`fanliangyi-dao/makearray`）走队伍系统实现。

  绝招实现见 `lib/kantele/combat/skills/performs/fanliangyi_dao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=150 门槛本版以 force>=40 代理；
  - LPC 招式表与 `practice_skill`（须持刀 qi50/neili50）未建模；
  - LPC master 中组阵成员还须激发紫霞神功（mapped force == zixia-shengong），
    本版以 队长触发方本地校验 代偿（见 makearray 模块）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "fanliangyi-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候太浅。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"makearray" => Kantele.Combat.Skills.Performs.FanliangyiDao.Makearray}
  end
end
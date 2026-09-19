defmodule Kantele.Combat.Skills.FurongJinzhen do
  @moduledoc """
  芙蓉金针（对照 `kungfu/skill/furong-jinzhen.c`）

  暗器载体：`valid_enable("throwing")`；
  `valid_force` 接受 基本暗器/芙蓉金针 共存。

  差异（TODO(migrate)）：
  - `xian`（金针现影）需暗器、芙蓉金针>=80、force>=120、neili>=150、目标存活且战斗中。
    内力对抗，成功造成 ap/5+random 伤害。
  """

  use Kantele.Combat.Skill

  @impl true
  def id(), do: "furong-jinzhen"

  @impl true
  def valid_enable(usage), do: usage == "throwing"

  @impl true
  def valid_force(force), do: force in ["basic-throwing", "furong-jinzhen"]

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"xian" => Kantele.Combat.Skills.Performs.FurongJinzhen.Xian}
  end
end
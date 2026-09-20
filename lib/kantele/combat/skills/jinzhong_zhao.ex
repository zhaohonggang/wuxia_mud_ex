defmodule Kantele.Combat.Skills.JinzhongZhao do
  @moduledoc """
  金钟罩（对照 `kungfu/skill/jinzhong-zhao.c`）

  护体内功载体：`valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jinzhong_zhao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=4000 门槛本版以 force>=350+str/con>=33 代理；
  - LPC `valid_damage` 被动（护体罡气反弹）与 `query_effect_parry` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jinzhong-zhao"

  @impl true
  def valid_enable(usage), do: usage == "parry"

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 350 ->
        {:error, "你的内功火候不够，难以修习这等神功。\n"}

      stats.con < 33 ->
        {:error, "你的先天根骨太差了，难以修习这等神功。\n"}

      stats.str < 33 ->
        {:error, "你的先天臂力太差了，难以修习这等神功。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, id()) ->
        {:error, "你的基本内功水平有限，无法领会更高深的金钟罩。\n"}

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
    %{"zhao" => Kantele.Combat.Skills.Performs.JinzhongZhao.Zhao}
  end
end
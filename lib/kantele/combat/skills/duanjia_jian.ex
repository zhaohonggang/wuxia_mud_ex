defmodule Kantele.Combat.Skills.DuanjiaJian do
  @moduledoc """
  段家剑法（对照 `kungfu/skill/duanjia-jian.c`）

  剑/杖法载体：`valid_enable("sword")`、`valid_enable("staff")`；
  `valid_force` 接受 基本剑法/基本杖法/段家剑法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/duanjia_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=300 / 基本剑法>=30 门槛本版以 force 等级代理；
  - LPC `practice_skill` 训练（qi 45 / neili 36）未建模（`practice_cost` 返回 nil）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanjia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "staff"]

  @impl true
  def valid_force(force), do: force in ["basic-sword", "basic-staff", "duanjia-jian"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候还不够。\n"}

      Stats.skill(stats, "duanjia-jian") > 0 && Stats.skill(stats, "force") < Stats.skill(stats, "duanjia-jian") ->
        {:error, "你的基本内功水平不够，难以修炼更深厚的段家剑法。\n"}

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
  def perform_list() do
    %{
      "lian" => Kantele.Combat.Skills.Performs.DuanjiaJian.Lian,
      "jing" => Kantele.Combat.Skills.Performs.DuanjiaJian.Jing
    }
  end
end
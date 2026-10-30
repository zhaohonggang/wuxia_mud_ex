defmodule Kantele.Combat.Skills.SunFinger do
  @moduledoc """
  孙指（对照 `kungfu/skill/sun-finger.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sun_finger/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：须男性 / str>=34 / dex>=30 / force>=240 / max_neili>=2000 /
    finger>=150 / finger>=sun-finger；
  - LPC 的「须空手（`query_temp("weapon")` 为空）」检查未写入 `valid_learn`（`character` 快照
    不含持械信息），由 practice 流程把关；
  - LPC `practice_skill` 已迁移：qi 60 / neili 100；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "sun-finger"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      gender_of(character) != "男性" ->
        {:error, "一阳指乃是纯阳玄功，你如何可以修习？\n"}

      Stats.str(stats) < 34 ->
        {:error, "你的先天膂力孱弱，无法领会一阳指。\n"}

      Stats.dex(stats) < 30 ->
        {:error, "你的先天身法孱弱，无法修炼一阳指。\n"}

      Stats.skill(stats, "force") < 240 ->
        {:error, "你的内功火候不够，无法学一阳指。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力太弱，无法练一阳指。\n"}

      Stats.skill(stats, "finger") < 150 ->
        {:error, "你的基本指法火候不够，无法学一阳指。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法水平有限，无法领会更高深的一阳指。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 100（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 100}

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{
      "dian" => Kantele.Combat.Skills.Performs.SunFinger.Dian,
      "heal" => Kantele.Combat.Skills.Performs.SunFinger.Heal,
      "qiankun" => Kantele.Combat.Skills.Performs.SunFinger.Qiankun
    }
  end
end

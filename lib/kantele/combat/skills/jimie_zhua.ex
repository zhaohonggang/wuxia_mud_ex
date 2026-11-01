defmodule Kantele.Combat.Skills.JimieZhua do
  @moduledoc """
  寂灭爪（对照 `kungfu/skill/jimie-zhua.c`）

  爪法载体：`valid_enable("claw")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/jimie_zhua/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手与 max_neili>=600，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N全身拔地而起，一式「众生无我」，双爪迅猛地抓向$n的$l",
      "force" => 100,
      "parry" => 5,
      "lvl" => 0
    },
    %{
      "action" => "$N大吼一声，接连发出四抓，一式「苦乐随缘」，双爪抓向$n的头部和胸部",
      "force" => 120,
      "parry" => 10,
      "lvl" => 10
    },
    %{
      "action" => "$N一式「烈火腾云」，双掌化指，霎时间，一股咄咄逼人的内力逼向$n",
      "force" => 80,
      "parry" => 10,
      "lvl" => 20
    },
    %{
      "action" => "$N双爪交错，一式「普度众生」，身行上扬，分别袭向$n左右腋空门",
      "force" => 220,
      "parry" => 15,
      "lvl" => 30
    },
    %{
      "action" => "$N一式「七星聚会」，右爪突出，左爪跟进，双爪相叠，抓向$n的胸口",
      "force" => 180,
      "parry" => 20,
      "lvl" => 40
    },
    %{
      "action" => "$N原地不动，一式「以逸待劳」，只待$n袭来，双爪袭向$n膻中大穴和裆部",
      "force" => 230,
      "parry" => 25,
      "lvl" => 50
    },
    %{
      "action" => "$N的双爪无数道劲气破空而出，，一式「天衣无缝」，迅疾无比地击向$n",
      "force" => 260,
      "parry" => 30,
      "lvl" => 55
    },
    %{
      "action" => "$N腾空高飞数丈，一式「佛门善地」，一时间空中出现无数$N的身影罩向$n",
      "force" => 190,
      "parry" => 40,
      "lvl" => 60
    }
  ]

  @impl true
  def id(), do: "jimie-zhua"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 jimie-zhua.c）
  @impl true
  def valid_learn(_stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练寂灭爪必须空手。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力太弱，无法学习寂灭爪。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"wuwo" => Kantele.Combat.Skills.Performs.JimieZhua.Wuwo}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

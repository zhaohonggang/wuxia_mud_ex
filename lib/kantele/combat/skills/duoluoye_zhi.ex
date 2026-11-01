defmodule Kantele.Combat.Skills.DuoluoyeZhi do
  @moduledoc """
  多罗叶指（对照 `kungfu/skill/duoluoye-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/duoluoye_zhi/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、max_neili>=1500、未并入参合指，
    本版以 force>=150 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N身形前倾，右指弹出一屡劲风，飘渺无形的击向$n的$l",
      "force" => 180,
      "attack" => 80,
      "dodge" => 15,
      "parry" => 30,
      "damage" => 70,
      "lvl" => 0
    },
    %{
      "action" => "$N手捏不动手印，轻轻跃起，双手回旋，将$n笼罩在指风之中",
      "force" => 200,
      "attack" => 90,
      "dodge" => 10,
      "parry" => 45,
      "damage" => 95,
      "lvl" => 40
    },
    %{
      "action" => "$N揉身而上，右指长驱直入，弛点$n的大穴，一派两败俱伤的打法",
      "force" => 250,
      "attack" => 100,
      "dodge" => 35,
      "parry" => 50,
      "damage" => 110,
      "lvl" => 80
    },
    %{
      "action" => "$N纵身跃起，居高临下，双手分别点向$n的各大要穴",
      "force" => 300,
      "attack" => 90,
      "dodge" => 10,
      "parry" => 45,
      "damage" => 120,
      "lvl" => 120
    },
    %{
      "action" => "$N将内力灌注于指间，一指戳出，勇不可挡，硬破入$n的招数中，击向$n的$l",
      "force" => 420,
      "attack" => 50,
      "dodge" => -15,
      "parry" => 30,
      "damage" => 100,
      "lvl" => 160
    },
    %{
      "action" => "$N跨步上前，突然连环三指击出，一气呵成，射出三屡指风击向$n",
      "force" => 260,
      "attack" => 150,
      "dodge" => 25,
      "parry" => 50,
      "damage" => 80,
      "lvl" => 200
    },
    %{
      "action" => "$N纵身而上，右手食指点出，缓缓按向$n的$l，似乎毫不着力",
      "force" => 500,
      "attack" => 60,
      "dodge" => 35,
      "parry" => 55,
      "damage" => 120,
      "lvl" => 240
    },
    %{
      "action" => "$N缓步上前，尽起全身功力，双指弹出数道指风，将$n完全笼罩在攻势之下",
      "force" => 450,
      "attack" => 70,
      "dodge" => 65,
      "parry" => 60,
      "damage" => 180,
      "lvl" => 280
    }
  ]

  @impl true
  def id(), do: "duoluoye-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 duoluoye-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "canhe-zhi") > 0 ->
        {:error, "你已将这种指法融入参合指，不必再分开练习了。\n"}

      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练多罗叶指必须空手。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法学习多罗叶指。\n"}

      not is_nil(max_neili) and max_neili < 1500 ->
        {:error, "你的内力太弱，无法练多罗叶指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的多罗叶指。\n"}

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
    %{"jimie" => Kantele.Combat.Skills.Performs.DuoluoyeZhi.Jimie}
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

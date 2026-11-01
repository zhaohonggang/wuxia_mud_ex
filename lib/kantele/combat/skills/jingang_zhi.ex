defmodule Kantele.Combat.Skills.JingangZhi do
  @moduledoc """
  大力金刚指（对照 `kungfu/skill/jingang-zhi.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`（须空手）。

  绝招实现见 `lib/kantele/combat/skills/performs/jingang_zhi/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求空手、str>=30、con>=32、max_neili>=300、
    finger>=jingang-zhi，本版以 force>=60 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N身体半蹲，右指中宫直进，一式「降龙伏虎」击向$n的$l",
      "force" => 80,
      "attack" => 20,
      "dodge" => -5,
      "parry" => 20,
      "damage" => 20,
      "lvl" => 0,
      "skill_name" => "降龙伏虎"
    },
    %{
      "action" => "$N轻轻一纵，居高临下，一式「普渡众生」，点向$n的周身大穴",
      "force" => 100,
      "attack" => 40,
      "dodge" => 0,
      "parry" => 15,
      "damage" => 25,
      "lvl" => 40,
      "skill_name" => "普渡众生"
    },
    %{
      "action" => "$N身形飘忽不定，一式「佛祖献花」，右指击向$n的$l",
      "force" => 110,
      "attack" => 30,
      "dodge" => -5,
      "parry" => 25,
      "damage" => 30,
      "lvl" => 80,
      "skill_name" => "佛祖献花"
    },
    %{
      "action" => "$N不动声色，突然一招「斩妖除魔」，左右双指分别指向$n的各大要穴",
      "force" => 150,
      "attack" => 40,
      "dodge" => -10,
      "parry" => 25,
      "damage" => 120,
      "lvl" => 60,
      "skill_name" => "斩妖除魔"
    },
    %{
      "action" => "$N摒指如刀，一招「五丁开山」，双指呈刀势从意想不到的角度劈向$n",
      "force" => 180,
      "attack" => 50,
      "dodge" => -15,
      "parry" => 30,
      "damage" => 160,
      "lvl" => 80,
      "skill_name" => "五丁开山"
    },
    %{
      "action" => "$N盘膝端坐，一招「佛法无边」，右手拇指弹出一道劲风，击向$n",
      "force" => 160,
      "attack" => 60,
      "dodge" => 5,
      "parry" => 30,
      "damage" => 100,
      "lvl" => 200,
      "skill_name" => "佛法无边"
    },
    %{
      "action" => "$N纵身而上，一招「金刚伏魔」，双手食指端部各射出一道青气击向$n",
      "force" => 180,
      "attack" => 60,
      "dodge" => -5,
      "parry" => 40,
      "damage" => 120,
      "lvl" => 225,
      "skill_name" => "金刚伏魔"
    },
    %{
      "action" => "$N脸上忽现祥和之气，一招「无色无相」，一指遥遥指向$n，似乎毫无劲力",
      "force" => 200,
      "attack" => 70,
      "dodge" => 15,
      "parry" => 50,
      "damage" => 180,
      "lvl" => 250,
      "skill_name" => "无色无相"
    }
  ]

  @impl true
  def id(), do: "jingang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 jingang-zhi.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练大力金刚指必须空手。\n"}

      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不够，无法学大力金刚指。\n"}

      (Stats.str(stats) < 30) or (Stats.con(stats) < 32) ->
        {:error, "你的先天条件不够，无法学大力金刚指。\n"}

      not is_nil(max_neili) and max_neili < 300 ->
        {:error, "你的内力太弱，无法练大力金刚指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的大力金刚指。\n"}

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
    %{
      "fumo" => Kantele.Combat.Skills.Performs.JingangZhi.Fumo,
      "san" => Kantele.Combat.Skills.Performs.JingangZhi.San
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  def actions(), do: @actions

end

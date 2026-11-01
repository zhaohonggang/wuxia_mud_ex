defmodule Kantele.Combat.Skills.FeifengWhip do
  @moduledoc """
  飞凤鞭法（对照 `kungfu/skill/feifeng-whip.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/feifeng_whip/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 还要求女性且持鞭，本版仅以 force>=30 代理；
  - 招式表与 `practice_skill` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N向上跃起，一招「凤凰展翅」，手中$w自下而上，击向$n的脸颊",
      "force" => 100,
      "dodge" => 0,
      "damage" => 20,
      "lvl" => 15,
      "skill_name" => "凤凰展翅"
    },
    %{
      "action" => "$N一招「彩凤栖梧」，手中$w直绕向$n的$l",
      "force" => 110,
      "dodge" => -10,
      "damage" => 30,
      "lvl" => 20,
      "skill_name" => "彩凤栖梧"
    },
    %{
      "action" => "$N一招「鸾凤和鸣」，手中$w腾空一卷，一声脆响入磬，猛地向$n劈头打下",
      "force" => 120,
      "dodge" => -15,
      "damage" => 40,
      "lvl" => 40,
      "skill_name" => "鸾凤和鸣"
    },
    %{
      "action" => "$N踏上一步，冲着$n轻佻一笑，手中$w却毫不停留，一招「游龙戏凤」，扫向$n的$l",
      "force" => 130,
      "dodge" => -30,
      "damage" => 60,
      "lvl" => 50,
      "skill_name" => "游龙戏凤"
    },
    %{
      "action" => "$N跃在半空，一招「龙飞凤舞」，手中$w如游龙洗空，长凤戏羽，乱雨倾盆般分点$n左右",
      "force" => 150,
      "dodge" => -35,
      "damage" => 70,
      "lvl" => 60,
      "skill_name" => "龙飞凤舞"
    },
    %{
      "action" => "$N向前急进，手中$w圈转如虹，一招「龙凤呈祥」，罩向$n前胸",
      "force" => 170,
      "dodge" => -40,
      "damage" => 85,
      "lvl" => 75,
      "skill_name" => "龙凤呈祥"
    }
  ]

  @impl true
  def id(), do: "feifeng-whip"

  @impl true
  def valid_enable(usage), do: usage in ["whip", "parry"]

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 feifeng-whip.c）
  @impl true
  def valid_learn(stats, character) do
    gender = gender_of(character)

    cond do
      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候太浅。\n"}

      gender != "女性" ->
        {:error, "大老爷们学这飞凤鞭？天资不足吧。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条长鞭才能练鞭法。\n"}

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
    %{"wu" => Kantele.Combat.Skills.Performs.FeifengWhip.Wu}
  end

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"

  def actions(), do: @actions

end

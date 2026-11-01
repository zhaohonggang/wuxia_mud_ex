defmodule Kantele.Combat.Skills.LeimingBian do
  @moduledoc """
  武学实装「leiming-bian」（源 leiming-bian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/leiming_bian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N将身一纵，跃在半空，一式「彩凤栖梧」，手中$w盘旋而下，鞭势灵动之至，击向$n$l",
      "force" => 100,
      "attack" => 90,
      "parry" => 60,
      "dodge" => -5,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "抽伤",
      "skill_name" => "彩凤栖梧"
    },
    %{
      "action" => "$N沉肩滑步，手中$w一抖，一式「凤凰展翅」，迅捷无比地分打左右两侧，$n顿时左右支绌，慌了手脚",
      "force" => 150,
      "attack" => 90,
      "parry" => 60,
      "dodge" => 5,
      "damage" => 50,
      "lvl" => 20,
      "damage_type" => "抽伤",
      "skill_name" => "凤凰展翅"
    },
    %{
      "action" => "$N将内力注入$w，蓦地使出一式「蛟龙戏凤」，$w矫夭飞舞，直如神龙破空一般抽向$n",
      "force" => 200,
      "attack" => 100,
      "parry" => 80,
      "dodge" => 10,
      "damage" => 80,
      "lvl" => 40,
      "damage_type" => "抽伤",
      "skill_name" => "蛟龙戏凤"
    },
    %{
      "action" => "$N一声清啸，手中$w一招「龙飞凤舞」，划出漫天鞭影铺天盖地地向$n卷来，势道猛烈之极",
      "force" => 250,
      "attack" => 100,
      "parry" => 80,
      "dodge" => -10,
      "damage" => 110,
      "lvl" => 60,
      "damage_type" => "抽伤",
      "skill_name" => "龙飞凤舞"
    },
    %{
      "action" => "$N面露微笑跨前一步，右手$w轻扬，缓缓使出一式「龙凤呈祥」，鞭势平和中正，不带丝毫霸气",
      "force" => 300,
      "attack" => 120,
      "parry" => 90,
      "dodge" => 1,
      "damage" => 130,
      "lvl" => 80,
      "damage_type" => "抽伤",
      "skill_name" => "龙凤呈祥"
    }
  ]

  @impl true
  def id(), do: "leiming-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  # LPC `valid_learn(object me)`（源 leiming-bian.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不足，没有办法练习鞭法, 多练些内力再来吧。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候太浅。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "whip" ->
        {:error, "你必须先找一条鞭子才能练鞭法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end

  @impl true
  def perform_list() do
    %{
      "cibei" => Kantele.Combat.Skills.Performs.LeimingBian.Cibei
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

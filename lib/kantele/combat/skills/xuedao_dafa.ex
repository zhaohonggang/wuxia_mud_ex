defmodule Kantele.Combat.Skills.XuedaoDafa do
  @moduledoc """
  武学实装「xuedao-dafa」（源 xuedao-dafa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force
  - perform/exert 路由骨架见 tmp/perf_out/xuedao_dafa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N高举手中$w，使出一招「磨牙吮血」，一刀斜劈$n的$l",
      "force" => 210,
      "attack" => 20,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 100,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "磨牙吮血"
    },
    %{
      "action" => "$N就地一滚，使一招「刺血满地」，手中$w卷向$n的大腿",
      "force" => 240,
      "attack" => 25,
      "parry" => 35,
      "dodge" => 45,
      "damage" => 120,
      "lvl" => 140,
      "damage_type" => "割伤",
      "skill_name" => "刺血满地"
    },
    %{
      "action" => "$N足尖一点，使出「血海茫茫」，刀锋自上而下直插$n的$l",
      "force" => 280,
      "attack" => 40,
      "parry" => 40,
      "dodge" => 52,
      "damage" => 130,
      "lvl" => 160,
      "damage_type" => "割伤",
      "skill_name" => "血海茫茫"
    },
    %{
      "action" => "$N使出一招「呕心沥血」，将$w舞得如白雾一般压向$n",
      "force" => 320,
      "attack" => 45,
      "parry" => 42,
      "dodge" => 58,
      "damage" => 140,
      "lvl" => 180,
      "damage_type" => "割伤",
      "skill_name" => "呕心沥血"
    },
    %{
      "action" => "$N低吼一声，使出「血口喷人」，举$w直劈$n的$l",
      "force" => 340,
      "attack" => 50,
      "parry" => 45,
      "dodge" => 65,
      "damage" => 150,
      "lvl" => 200,
      "damage_type" => "割伤",
      "skill_name" => "血口喷人"
    },
    %{
      "action" => "$N使出「血迹斑斑」，飞身斜刺，忽然反手一刀横斩$n的腰部",
      "force" => 360,
      "attack" => 55,
      "parry" => 60,
      "dodge" => 70,
      "damage" => 160,
      "lvl" => 220,
      "damage_type" => "割伤",
      "skill_name" => "血迹斑斑"
    },
    %{
      "action" => "$N使一式「以血还血」，挥刀直指$n的胸口",
      "force" => 390,
      "attack" => 60,
      "parry" => 55,
      "dodge" => 80,
      "damage" => 170,
      "lvl" => 240,
      "damage_type" => "割伤",
      "skill_name" => "以血还血"
    },
    %{
      "action" => "$N刀锋虚点，使出一招「血流满面」，转身举$w横劈$n的面门",
      "force" => 420,
      "attack" => 70,
      "parry" => 60,
      "dodge" => 90,
      "damage" => 185,
      "lvl" => 260,
      "damage_type" => "割伤",
      "skill_name" => "血流漫面"
    }
  ]

  @impl true
  def id(), do: "xuedao-dafa"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "force", "parry"]

  @impl true
  def valid_force(force), do: force in ["longxiang-gong", "xiaowuxiang", "mizong-neigong"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC hit_ob 为「血量越低越易触发追加攻击（COMBAT_D->do_attack）」机制，
  # 本引擎无跨进程二次出招基础设施，故暂不迁移；引擎以 function_exported? 守卫，
  # 缺失 hit_ob 时安全回退 {0, nil, []}。

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

  # LPC `valid_learn(object me)`（源 xuedao-dafa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)
    personality = personality_of(character)

    cond do
      (personality == "光明磊落") or (personality == "狡黠多变") ->
        {:error, "你心中暗道：这血刀大法邪气太重，甚过诡异，莫不是专门设来害人的？\n"}

      Stats.str(stats) < 28 ->
        {:error, "你先天膂力孱弱，无法修炼血刀大法。\n"}

      Stats.dex(stats) < 26 ->
        {:error, "你先天身法太差，无法修炼血刀大法。\n"}

      (gender == "无性") and (Stats.skill(stats, "xuedao-dafa") > 29) ->
        {:error, "你无根无性，阴阳不调，难以领会高深的血刀大法。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的基本内功火候不足，不能学血刀大法。\n"}

      not is_nil(max_neili) and max_neili < 1600 ->
        {:error, "你的内力修为不足，不能学血刀大法。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功水平不够，难以锻炼更深厚的血刀大法。\n"}

      (lvl > 120) and (Stats.skill(stats, "blade") < lvl) ->
        {:error, "你的基本刀法水平不够，难以锻炼更深厚的血刀大法。\n"}

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
      "chi" => Kantele.Combat.Skills.Performs.XuedaoDafa.Chi,
      "shi" => Kantele.Combat.Skills.Performs.XuedaoDafa.Shi,
      "xue" => Kantele.Combat.Skills.Performs.XuedaoDafa.Xue,
      "ying" => Kantele.Combat.Skills.Performs.XuedaoDafa.Ying
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.XuedaoDafa.Powerup,
      "resurrect" => Kantele.Combat.Skills.Performs.XuedaoDafa.Resurrect
    }
  end

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil

end

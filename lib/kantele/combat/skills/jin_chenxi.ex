defmodule Kantele.Combat.Skills.JinChenxi do
  @moduledoc """
  武学实装「jin-chenxi」（源 jin-chenxi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 3 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jin_chenxi/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施展",
      "force" => 284,
      "attack" => 51,
      "parry" => 4,
      "dodge" => -29,
      "damage" => 58,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 303,
      "attack" => 93,
      "parry" => 13,
      "dodge" => -21,
      "damage" => 161,
      "lvl" => 150,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N施出一招",
      "force" => 384,
      "attack" => 98,
      "parry" => 54,
      "dodge" => -12,
      "damage" => 233,
      "lvl" => 200,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "jin-chenxi"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  @doc """
  学习门槛（对照 `jin-chenxi.c` valid_learn）

  - `huntian-baojian > 0` → 已合一，拒绝
  - 必须空手
  - `me->query("con") < 35` → 根骨（Stats.query_con）
  - `unarmed`/`force` (2 参) < 220 → 拳脚/内功门槛
  - `me->query("max_neili") < 6000` → vitals
  - `me->query_skill("dian-canghai", 1) - 10 < 本门` → 需先修靛沧海
  LPC 以 `return 1` 收尾。（注：LPC 文案含颜色宏 HIY/NOR，此处取纯文本。）
  """
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "huntian-baojian") > 0 ->
        {:error, "你已经将浑天宝鉴神功合一，不必再单独学习。\n"}

      Skill.wielding?(character) or Skill.secondary_wielding?(character) ->
        {:error, "修行金晨曦心法必须空手。\n"}

      Stats.query_con(stats) < 35 ->
        {:error, "你身子骨太弱，无法练习浑天宝鉴神功。\n"}

      Stats.skill(stats, "unarmed") < 220 ->
        {:error, "你的拳脚火候无法学习金晨曦心法。\n"}

      Stats.skill(stats, "force") < 220 ->
        {:error, "你的内功火候无法学习金晨曦心法。\n"}

      not is_integer(max_neili) or max_neili < 6000 ->
        {:error, "你的内力修为太差，无法学习金晨曦心法。\n"}

      Stats.skill(stats, "dian-canghai") - 10 < Stats.skill(stats, id()) ->
        {:error, "你必须先提高你的靛沧海心法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  def actions(), do: @actions
end

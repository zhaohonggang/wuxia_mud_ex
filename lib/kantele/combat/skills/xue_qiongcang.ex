defmodule Kantele.Combat.Skills.XueQiongcang do
  @moduledoc """
  武学实装「xue-qiongcang」（源 xue-qiongcang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xue_qiongcang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N施展",
      "force" => 261,
      "attack" => 21,
      "parry" => 9,
      "dodge" => 41,
      "damage" => 33,
      "lvl" => 0,
      "damage_type" => "震伤"
    },
    %{
      "action" => "$N陡然使出",
      "force" => 373,
      "attack" => 103,
      "parry" => -41,
      "dodge" => -61,
      "damage" => 191,
      "lvl" => 150,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N施出一招",
      "force" => 424,
      "attack" => 139,
      "parry" => -54,
      "dodge" => -72,
      "damage" => 253,
      "lvl" => 200,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N站立不动，一声暴喝，施出",
      "force" => 484,
      "attack" => 198,
      "parry" => -54,
      "dodge" => -67,
      "damage" => 239,
      "lvl" => 200,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "xue-qiongcang"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc """
  学习门槛（对照 `xue-qiongcang.c` valid_learn，LPC 以 `return 1` 收尾，全显式门）
  """
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "huntian-baojian") > 0 ->
        {:error, "你已经将浑天宝鉴神功合一，不必再单独学习。\n"}
      Skill.wielding?(character) or Skill.secondary_wielding?(character) ->
        {:error, "修行血穹苍心法必须空手。\n"}
      Stats.query_con(stats) < 35 ->
        {:error, "你身子骨太弱，无法练习浑天宝鉴神功。\n"}
      Stats.skill(stats, "unarmed") < 240 ->
        {:error, "你的拳脚火候无法学习血穹苍心法。\n"}
      Stats.skill(stats, "force") < 240 ->
        {:error, "你的内功火候无法学习血穹苍心法。\n"}
      not is_integer(max_neili) or max_neili < 7000 ->
        {:error, "你的内力修为太差，无法学习血穹苍心法。\n"}
      Stats.skill(stats, "jin-chenxi") - 10 < Stats.skill(stats, id()) ->
        {:error, "你必须先提高你的金晨曦心法。\n"}
      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

end

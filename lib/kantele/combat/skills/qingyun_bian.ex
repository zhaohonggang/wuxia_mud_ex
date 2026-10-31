defmodule Kantele.Combat.Skills.QingyunBian do
  @moduledoc """
  青云鞭法（对照 `kungfu/skill/qingyun-bian.c`）

  鞭法载体：`valid_enable("whip")` / `valid_enable("parry")`。

  已按 LPC 迁移（2026-10-31）：

    - 10 式静态招式表（源**无** `lvl` 字段 ⇒ 全部 `lvl == 0`，故任意等级都可抽到全部招式）。
    - `force` / `damage` 是**动态值**（`max_neili / 4` 与 `shen / 1500`，10 式公式相同），
      由 `query_action/3` 在拿到出招者快照后注入，见 `dynamic_values/2`。
    - `valid_learn/2`：`max_neili >= 500` / `shaolin-xinfa >= 80` / 正气（`shen`）双段门。

  未建模：

    - LPC `valid_learn` 的「须持鞭」检查（`weapon->query("skill_type") == "whip"`）——
      学习事件携带的角色切片不含持械信息，沿用本仓既有约定（`bagua_dao.ex` 等）由
      practice 流程把关，不写入 `valid_learn`。
    - 源 `query_skill_name` 取 `level >= action[i]["lvl"]` 且全表 `lvl == 0`，故恒返回
      最后一式「掩日」——本仓沿用基类按表推导，不额外复现该源内怪癖。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  # 源 10 式：均无 "lvl"（视为 0）、无 "attack"/"parry" 字段。
  # "force"/"damage" 由 dynamic_values/2 注入，此处不写死。
  @actions [
    %{
      "action" => "$N一招 聚火 ,手扬鞭起，手中$w将$n团团围住，内力一吐，鞭圈匀速缩小。",
      "dodge" => -10,
      "lvl" => 0,
      "skill_name" => "聚火",
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左手虚幻，右手$w一招 起光 ,手中$w由似一条青龙迅速击向$n。",
      "dodge" => 5,
      "lvl" => 0,
      "skill_name" => "起光",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N腾空而起，手中$w舞成圆环，一招 招雨 压向$n,令$n无处可躲。",
      "dodge" => 10,
      "lvl" => 0,
      "skill_name" => "招雨",
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N力贯鞭梢，一招 动雷 ，手中$w舞出满天鞭影，排山倒海般扫向$n全身",
      "dodge" => -5,
      "lvl" => 0,
      "skill_name" => "动雷",
      "damage_type" => "淤伤"
    },
    %{
      "action" =>
        "$N往前一纵, 但见$N身形一转，一招 移电 ，手中$w如鬼魅一般，神不知鬼不觉地袭向$n的$l！",
      "dodge" => -10,
      "lvl" => 0,
      "skill_name" => "移电",
      "damage_type" => "刺伤"
    },
    # 源此式缺 "damage_type"（保真：不补）
    %{
      "action" => "$N手持$w,力贯鞭稍，一招 剪虹 手中$w犹如彩虹般击向$n,已将$n笼罩于鞭下。",
      "dodge" => -20,
      "lvl" => 0,
      "skill_name" => "剪虹"
    },
    %{
      "action" =>
        "$N左手虚晃，右脚突然向前迈出，一招 止风 ，右手$w如同鬼魅一般无声无息的刺向$n!",
      "dodge" => 0,
      "lvl" => 0,
      "skill_name" => "止风",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N向前纵出，身体飞过$n头顶，一招 断云 手中$w击向$n的$l",
      "dodge" => 100,
      "lvl" => 0,
      "skill_name" => "断云",
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N手中$w晃出满天鞭影，一招 遮月 虚虚实实的鞭影，铺天盖地的击向$n",
      "dodge" => 50,
      "lvl" => 0,
      "skill_name" => "遮月",
      "damage_type" => "淤伤"
    },
    %{
      "action" => "$N一招 掩日 手中$w形似蛟龙又似飞蝗,密不透风的罩向$n！",
      "dodge" => 40,
      "lvl" => 0,
      "skill_name" => "掩日",
      "damage_type" => "淤伤"
    }
  ]

  @impl true
  def id(), do: "qingyun-bian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "whip"]

  @doc "练招消耗：LPC practice_skill 扣 qi 30（须持鞭，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 30, neili: 0}

  # LPC valid_learn：
  #   max_neili >= 500
  #   shaolin-xinfa >= 80
  #   lvl <= 150: lvl > 10 且 shen < t*20（t=1）→ 拒
  #   lvl  > 150: shen < 11100 + (lvl - 100) * 1000 → 拒
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    lvl = Stats.skill(stats, id())
    shen = shen_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不足，没有办法练青云鞭法, 多练些内力再来吧。\n"}

      Stats.skill(stats, "shaolin-xinfa") < 80 ->
        {:error, "你的少林心法火候太浅。\n"}

      lvl <= 150 and lvl > 10 and shen < 20 ->
        {:error, "你的正气太低了。\n"}

      lvl > 150 and shen < 11_100 + (lvl - 100) * 1000 ->
        {:error, "你的正气太低了。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  # 完整 Character 走 meta.stats.shen；learn 事件切片不带 stats，按 0 处理
  defp shen_of(%{meta: %{stats: %{shen: shen}}}) when is_integer(shen), do: shen
  defp shen_of(_), do: 0

  @doc """
  带出招者上下文的选招：10 式的 `force`/`damage` 用出招者快照实时生成

  LPC 原文（10 式共用同一公式）：

      "force"  : (int)this_player()->query("max_neili") / 4,
      "damage" : (int)this_player()->query("shen") / 1500,

  `attacker` 为 `Kantele.Combat.Fighter` 快照（含 `:max_neili` / `:shen`）。
  """
  @impl true
  def query_action(level, rng, attacker) do
    @actions
    |> Skill.pick_action(level, rng)
    |> Map.merge(dynamic_values(attacker))
  end

  defp dynamic_values(attacker) do
    %{
      "force" => div(max_neili_of_fighter(attacker), 4),
      "damage" => div(shen_of_fighter(attacker), 1500)
    }
  end

  defp max_neili_of_fighter(%{max_neili: n}) when is_integer(n), do: n
  defp max_neili_of_fighter(_), do: 0

  defp shen_of_fighter(%{shen: n}) when is_integer(n), do: n
  defp shen_of_fighter(_), do: 0

  # 无出招者上下文（展示/测试）：动态字段按 0 处理，避免崩
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    @actions
    |> Skill.pick_action(level, rng)
    |> Map.merge(%{"force" => 0, "damage" => 0})
  end

  @doc "招式名 -> 招式数据（供 score/look 展示；动态字段为 0）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "duan" => Kantele.Combat.Skills.Performs.QingyunBian.Duan
    }
  end
end

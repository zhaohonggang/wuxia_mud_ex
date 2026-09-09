defmodule Kantele.Quest.Reward do
  @moduledoc """
  任务奖励计算（对应 LPC adm/daemons/questd.c 的阶梯奖励与里程碑 special_bonus）

  纯函数：按任务类型给基础奖励，按 `level`（难度）与 `quest_count`（连续完成次数）
  放大，再叠加 turn_in 配置奖励与最大值里程碑 bonus。奖励的实际应用在宿主层
  （`quest_event`），本模块不碰玩家数据。

  - `base/1`：类型基础档（可调）
  - `scale/3`：level 每级 +10%，连续完成前 10 次每次 +5%
  - `merge/2`：同类键求和
  - `milestone_bonus/1`：里程碑 bonus（`Quest.milestone/1` 命中后）
  - `final/3`：最终奖励（读任务 meta 的 type/level + 连续计数，任务不在在办则原样返回 turn_rewards）
  """

  alias Kantele.Quest

  @doc "各类型基础奖励（可调）"
  def base("kill"), do: %{exp: 300, potential: 120, score: 60, weiwang: 2, gongxian: 15}

  def base("letter"), do: %{exp: 60, potential: 30, score: 20, weiwang: 1, gongxian: 3}

  def base(_), do: %{exp: 100, potential: 50, score: 30, weiwang: 1, gongxian: 5}

  @doc "难度/连续放大：level 每级 +10%，连续完成前 10 次每次 +5%（向下取整）"
  def scale(rewards, level, streak) when is_map(rewards) do
    level_factor = max(level || 1, 1) * 0.1
    streak_factor = min(max(streak || 0, 0), 10) * 0.05
    factor = 1 + level_factor + streak_factor

    Map.new(rewards, fn {key, value} -> {key, round(value * factor)} end)
  end

  @doc "叠加奖励（相同键求和）"
  def merge(rewards_a, rewards_b) do
    Map.merge(rewards_a || %{}, rewards_b || %{}, fn _key, a, b -> a + b end)
  end

  @doc "里程碑 bonus（按 tier 阶梯）"
  def milestone_bonus(tier) when is_integer(tier) and tier > 0 do
    %{exp: tier * 20, potential: tier * 10, score: tier * 4, gongxian: tier}
  end

  def milestone_bonus(_), do: %{}

  @doc """
  任务完成最终奖励 = 类型基础 ×（level/连续）放大 + turn_in 配置奖励 + 里程碑 bonus。

  - `quest_id` 为空或任务不在在办中：原样返回 `turn_rewards`（纯交物路径）。
  - 连续计数按「本次完成后」的 `quest_count + 1` 计算（阶梯/double 判断用新值）。
  """
  def final(quest_state, quest_id, turn_rewards) when is_binary(quest_id) and quest_id != "" do
    streak = Quest.quest_count(quest_state)

    case Quest.get_todo(quest_state, quest_id) do
      %{meta: meta} ->
        type = meta[:type] || "default"
        level = meta[:level] || 1
        combined = merge(scale(base(type), level, streak + 1), turn_rewards)

        case Quest.milestone(streak + 1) do
          {:ok, tier} -> merge(combined, milestone_bonus(tier))
          :none -> combined
        end

      _ ->
        turn_rewards || %{}
    end
  end

  def final(_quest_state, _quest_id, turn_rewards), do: turn_rewards || %{}
end
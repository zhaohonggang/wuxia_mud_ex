defmodule Kantele.Character.LearnGate do
  @moduledoc """
  学习/练习门槛集中校验（b2 捆绑 b1/b3/b4/b5）

  - **b1 潜能池**：可用潜能 = `potential - learned_points`（learn.c:124），
    每次 learn/practice 成功记 `Stats.spend_potential/2`
  - **b3 耗精**：`jing_cost = (100 + skill*2) / int`，初学（0 级）×2
    （learn.c:117-122）。开关 `:enable_jing_learn_cost`，默认关闭；
    开启后逐级扣精，精尽中断但已学部分保留（learn.c:161-203）
  - **b4 经验门**：武功类技能 `(level+1)³/10 <= combat_exp` 才许升下一级
    （can_improve_skill，skill.c:278）。开关 `:enable_exp_gate`，默认关闭。
    只拦学习不追溯存量
  - **b5 内功互斥**：学新内功前，已学的其他内功对其 valid_force? 检查
    （learn.c can_learn/229-251），冲突拒绝。始终启用，不追溯存量

  分工约束：teach/2 在 NPC 进程拿学生**快照**做门槛判定；
  逐级扣费在学生进程 learn_result 实时执行，两侧不得重复扣费。

  ## 开关配置

      config :ex_venture, enable_jing_learn_cost: true
      config :ex_venture, enable_exp_gate: true
  """

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @learn_cost 2

  @doc "单级学习/练习的潜能消耗"
  def learn_cost(), do: @learn_cost

  # ---- 开关 ----

  def jing_cost_enabled?(),
    do: Application.get_env(:ex_venture, :enable_jing_learn_cost, false)

  def exp_gate_enabled?(),
    do: Application.get_env(:ex_venture, :enable_exp_gate, false)

  # ---- b3：耗精公式 ----

  @doc "单级学习的精消耗；0 级初学 ×2（learn.c:117-122）"
  def jing_cost(%Stats{} = stats, skill_id) do
    level = Stats.skill(stats, skill_id)
    cost = div(100 + level * 2, max(stats.int, 1))

    if level == 0, do: cost * 2, else: cost
  end

  # ---- b4：经验门 ----

  @doc "下一级是否仍在实战经验允许范围内：(lvl+1)³/10 <= combat_exp"
  def can_improve?(%Stats{} = stats, skill_id) do
    next = Stats.skill(stats, skill_id) + 1
    div(next * next * next, 10) <= stats.combat_exp
  end

  # ---- b5：内功互斥 ----

  @doc """
  新学 skill_id 是否与已学内功冲突（learn.c can_learn/229-251）

  返回冲突的已学内功 id 或 nil。
  """
  def force_conflict(%Stats{} = stats, skill_id) do
    new_module = Skills.get(skill_id)

    with true <- new_module != nil,
         true <- new_module.valid_enable("force"),
         false <- new_module.valid_force("*") do
      # 双向检查：新技能拒绝已学内功 OR 已学内功拒绝新技能
      Enum.find_value(Skills.all(), fn {other_id, other_module} ->
        learned? =
          other_id != skill_id and other_module.valid_enable("force") and
            Stats.skill(stats, other_id) > 0

        if learned? and (not other_module.valid_force(skill_id) or
                          not new_module.valid_force(other_id)),
          do: other_id
      end)
    else
      # 非内功技能：仅检查已学 force 是否拒绝它
      _ ->
        if new_module != nil do
          Enum.find_value(Skills.all(), fn {other_id, other_module} ->
            learned? =
              other_id != skill_id and other_module.valid_enable("force") and
                Stats.skill(stats, other_id) > 0

            if learned? and not other_module.valid_force(skill_id), do: other_id
          end)
        end
    end
  end

  @doc "互斥冲突提示文案（learn.c:246-250）"
  def conflict_message(nil, _skill_id), do: nil

  def conflict_message(other_id, skill_id) do
    "你发现自身所学的#{title(other_id)}和#{title(skill_id)}冲突不已，根本没办法并存。\n"
  end

  # ---- 师父侧快照总闸（teach/2 调用）----

  @doc """
  快照门槛：潜能(b1)、经验门(b4)、内功互斥(b5)

  通过返回 :ok；否则 {:error, 文案}。
  """
  def snapshot_gate(%Stats{} = student_stats, skill_id) do
    cond do
      Stats.available_potential(student_stats) < @learn_cost ->
        {:error, "你的潜能不足，先去实战中磨练磨练吧。\n"}

      exp_gate_enabled?() and not can_improve?(student_stats, skill_id) ->
        {:error, "也许是缺乏实战经验，你对师父的回答总是无法领会。\n"}

      conflict = force_conflict(student_stats, skill_id) ->
        {:error, conflict_message(conflict, skill_id)}

      true ->
        :ok
    end
  end

  # ---- 学生侧单级判定（learn_levels / practice 循环用）----

  @doc """
  本级能否继续学：潜能足额 + 精够（开关开时）+ 经验门通过

  返回 :ok | {:halt, 文案}。文案为中断原因（已学部分不回滚）。
  """
  def level_gate(vitals, %Stats{} = stats, skill_id) do
    cond do
      Stats.available_potential(stats) < @learn_cost ->
        {:halt, "你的潜能不足，先去实战中磨练磨练吧。\n"}

      jing_cost_enabled?() and vitals.jing < jing_cost(stats, skill_id) ->
        {:halt, "然而你今天太累了，无法再进行任何学习了。\n"}

      exp_gate_enabled?() and not can_improve?(stats, skill_id) ->
        {:halt, "也许是缺乏实战经验，你无法继续领会更高深的境界。\n"}

      true ->
        case force_conflict(stats, skill_id) do
          nil -> :ok
          other_id -> {:halt, conflict_message(other_id, skill_id)}
        end
    end
  end

  @doc "本级学习结算：记潜能消耗 + 扣精（开关开启时；耗精按本级等级计）"
  def pay_level(vitals, %Stats{} = stats, skill_id) do
    jing = jing_cost(stats, skill_id)
    stats = Stats.spend_potential(stats, @learn_cost)

    vitals =
      if jing_cost_enabled?() do
        Kantele.Character.Vitals.damage(vitals, :jing, jing)
      else
        vitals
      end

    {vitals, stats}
  end

  defp title("liuxin-jian"), do: "柳心剑法"
  defp title("liuxi-neigong"), do: "柳溪内功"
  defp title(other), do: other
end

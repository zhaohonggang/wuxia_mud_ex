defmodule Kantele.Character.Closed do
  @moduledoc """
  闭关修行的纯逻辑层（对应 LPC cmds/skill/closed.c 与 adm/daemons/closed.c / CLOSE_D）。

  与 `Kantele.Character.Scheme` / `Kantele.Character.ClosedStepEvent` 的关系同
  `Scheme`/`SchemeStepEvent`：本模块只负责门槛判定与每拍转化（数据变换），
  不含心跳调度与渲染；调度/渲染由 `Kantele.Character.ClosedStepEvent` 负责。

  ## 与 LPC 的差异（已知，见 docs/B5 §P-B）
  - Kantele 无 ultrap（大宗师）判定，以「已拜师」(meta.family) 近似门槛。
  - Kantele 无 neili/jingli 字段参与闭关增益，故省略 improve_neili/improve_jingli；
    增益集中在 combat_exp 与随机武学技能等级。
  - 离线持久化（CLOSE_D 守护进程跨会话恢复）不在本期范围；运行态存于
    `conn.session[:closed]`（随玩家进程存活，断线不保留），与 respirate 一致。

  ## 核心机制（对齐 LPC closing()）
  - 每拍消耗 `50 + random(100)` 点可用潜能（封顶于总潜能）。
  - 增长 combat_exp：`(50 + random(100)) * (100 + int) / 100`（本端口无 martial-cognize）。
  - 随机挑选一项已达 1 级的武学技能，提升 `5 + random(10)` 级。
  - 潜能耗尽时返回 `{:done, ...}`，由调用方收尾出关。
  """

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @min_potential 10_000

  # 武学技能 allow-list（对应 LPC filter_skill 的 martial 类型 + valid_enable force）
  @martial_skills ~w(
    unarmed sword blade staff whip club hammer spear dagger throwing finger
    claw painting dodge parry force lance fist hand leg
  )

  @doc """
  门槛判定：返回 `{:ok, character}` 或 `{:error, msg}`。

  `room_flags` 为房间标志列表（含 `"no_fight"` 才允许闭关），默认空列表。
  """
  def gate(character, room_flags \\ []) do
    meta = character.meta
    vitals = meta.vitals
    stats = meta.stats

    cond do
      Combat.busy?(meta.combat) ->
        {:error, "你现在正忙着呢。\n"}

      Combat.fighting?(meta.combat) ->
        {:error, "战斗中不能闭关。\n"}

      is_nil(meta.family) ->
        {:error, "你还没有拜师，无法闭关修行。\n"}

      Stats.available_potential(stats) < @min_potential ->
        {:error, "你的潜能不够，没法闭关修行。（需要至少 10000 潜能）\n"}

      qi_ratio(vitals) < 90 ->
        {:error, "你现在的气太少了，无法静心闭关。\n"}

      jing_ratio(vitals) < 90 ->
        {:error, "你现在的精太少了，无法静心闭关。\n"}

      not ("no_fight" in room_flags) ->
        {:error, "在这里闭关？不太安全吧？\n"}

      true ->
        {:ok, character}
    end
  end

  @doc """
  每拍转化（对应 LPC closed.c closing()）。

  返回：
  - `{:done, character, messages}`：潜能耗尽，结束闭关
  - `{:ok, character, messages}`：继续，调用方负责续拍

  `rng` 为注入的随机函数（默认 LPC 风格 `0..n-1`），便于测试。
  """
  def tick(character, rng \\ &lpc_random/1) do
    stats = character.meta.stats
    avail = Stats.available_potential(stats)

    if avail <= 0 do
      {:done, character,
       ["你的潜能耗尽了。\n", "$N睁开双目，缓缓吐了一口气，站了起来。\n"]}
    else
      # LPC: learned_points += 50 + random(100)，封顶于总潜能
      cost = min(avail, 50 + rng.(100))
      stats = Stats.spend_potential(stats, cost)

      # combat_exp：LPC exp_inc = (50+random(100)) * (100+cognize)/500 * (100+int)/100
      # 本端口无 martial-cognize，仅取 int 因子
      exp_inc = trunc((50 + rng.(100)) * (100 + Stats.int(stats)) / 100)
      stats = %{stats | combat_exp: stats.combat_exp + exp_inc}

      {stats, skill_msgs} = improve_random_martial(stats, rng)
      new_character = %{character | meta: %{character.meta | stats: stats}}

      msgs = maybe_messages(rng) ++ skill_msgs
      {:ok, new_character, msgs}
    end
  end

  # ---------------------------------------------------------------------------
  # 内部工具
  # ---------------------------------------------------------------------------

  defp improve_random_martial(%Stats{skills: skills} = stats, rng) do
    candidates =
      skills
      |> Enum.filter(fn {name, lvl} ->
        name in @martial_skills and is_integer(lvl) and lvl >= 1
      end)
      |> Enum.map(fn {name, _} -> name end)

    case candidates do
      [] ->
        {stats, []}

      list ->
        name = Enum.at(list, rng.(length(list)))
        inc = 5 + rng.(10)
        new_skills = Map.update(skills, name, inc, &(&1 + inc))
        {%{stats | skills: new_skills}, ["你对#{name}的修为有所感悟。\n"]}
    end
  end

  defp maybe_messages(rng) do
    if rng.(10) == 0 do
      ["闭关修炼中...\n"]
    else
      []
    end
  end

  defp qi_ratio(%{qi: qi, max_qi: max_qi}) when is_integer(max_qi) and max_qi > 0,
    do: div(qi * 100, max_qi)

  defp qi_ratio(_), do: 0

  defp jing_ratio(%{jing: jing, max_jing: max_jing}) when is_integer(max_jing) and max_jing > 0,
    do: div(jing * 100, max_jing)

  defp jing_ratio(_), do: 0

  defp lpc_random(n) when n > 0, do: :rand.uniform(n) - 1
  defp lpc_random(_), do: 0
end

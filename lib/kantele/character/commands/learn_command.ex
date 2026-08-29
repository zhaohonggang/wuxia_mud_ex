defmodule Kantele.Character.LearnCommand do
  @moduledoc """
  学习命令：`learn <技能> <师父> [x次数]`

  流程：向房间发 `skills/learn`，房间找到师父 NPC 后转发
  `skills/teach`；由师父侧校验门槛并回执 `skills/learn-result`。
  支持 xN 后缀一次请授多级（如 `learn sword 王重九 x10`），
  实际级数受师生差距与潜能约束。次数随事件数据传递，
  不放 conn.assigns（assigns 不跨 foreman 消息存活）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.SkillsEvent

  def run(conn, params) do
    {name, times} = parse_times(params["name"])

    # 房间上下文中的角色是 Trimmed 版本，学生属性需随事件自带
    conn
    |> event("skills/learn", %{
      skill: params["skill"],
      name: name,
      times: times,
      student_stats: conn.character.meta.stats,
      student_family: conn.character.meta.family
    })
    |> assign(:prompt, false)
  end

  # 容错处理：多余的 xN 词被丢弃，以最后一个为准（`王重九 x2 x2` → 2）
  defp parse_times(name) do
    {tokens, times} =
      name
      |> to_string()
      |> String.split()
      |> Enum.reduce({[], 1}, fn token, {acc, t} ->
        case Regex.run(~r/^x(\d+)$/i, token) do
          [_, n] -> {acc, String.to_integer(n)}
          _ -> {[token | acc], t}
        end
      end)

    {Enum.reverse(tokens) |> Enum.join(" "), min(times, SkillsEvent.max_times())}
  end
end

defmodule Kantele.Character.PracticeCommand do
  @moduledoc """
  练习命令：`practice <技能>`（消耗 qi/neili 换等级）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.LearnGate
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  def run(conn, params) do
    character = conn.character
    skill_id = params["skill"]
    module = Skills.get(skill_id)

    cond do
      is_nil(module) ->
        render_error(conn, "没有这项武功。\n")

      module.practice_cost() == nil ->
        render_error(conn, "#{skill_title(skill_id)}只能用学(learn)的来增加熟练度。\n")

      true ->
        practice(conn, character, skill_id, module)
    end
  end

  defp practice(conn, character, skill_id, module) do
    stats = character.meta.stats
    cost = module.practice_cost()
    vitals = character.meta.vitals

    with :ok <- module.valid_learn(stats),
         :ok <- conflict_gate(stats, skill_id),
         :ok <- exp_gate(stats, skill_id),
         :ok <- check_jing(vitals),
         :ok <- check_vitals(vitals, cost),
         :ok <- check_available_potential(stats) do
      {stats, _gained?} = Stats.improve_skill(stats, skill_id)
      # b1：潜能消耗记入 learned_points 池（可用潜能 = potential - learned_points）
      stats = Stats.spend_potential(stats, LearnGate.learn_cost())
      {stats, extra} = maybe_unlock_perform(skill_id, stats)

      vitals =
        vitals
        |> Kantele.Character.Vitals.damage(:qi, cost.qi)
        |> Map.put(:neili, max(vitals.neili - cost.neili, 0))
        |> Kantele.Character.Vitals.recalculate_max_neili(stats)

      meta =
        character.meta
        |> Map.put(:stats, stats)
        |> Map.put(:vitals, vitals)

      character = %{character | meta: meta}
      Records.save(character)

      message = "你演练了一遍#{skill_title(skill_id)}，似乎又精进了一分。#{extra}"

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: message})
      |> prompt(CommandView, "prompt", %{})
    else
      {:error, message} -> render_error(conn, message)
    end
  end

  # b5：与已学内功互斥冲突
  defp conflict_gate(stats, skill_id) do
    case LearnGate.force_conflict(stats, skill_id) do
      nil -> :ok
      other -> {:error, LearnGate.conflict_message(other, skill_id)}
    end
  end

  # b4：实战经验门（开关默认关闭）
  defp exp_gate(stats, skill_id) do
    if LearnGate.exp_gate_enabled?() and not LearnGate.can_improve?(stats, skill_id) do
      {:error, "也许是缺乏实战经验，你的练习总没法进步。\n"}
    else
      :ok
    end
  end

  # 练习需精神饱满（与打坐同款 70% 门槛；LPC practice.c 无此门，取统一值）
  defp check_jing(%{jing: jing, max_jing: max_jing}) when max_jing > 0 do
    if div(jing * 100, max_jing) < 70 do
      {:error, "你现在精神不济，无法专心练习。\n"}
    else
      :ok
    end
  end

  defp check_jing(_vitals), do: :ok

  defp check_available_potential(stats) do
    if Stats.available_potential(stats) >= LearnGate.learn_cost() do
      :ok
    else
      {:error, "你的潜能不足，先去实战中磨练磨练吧。\n"}
    end
  end

  defp check_vitals(vitals, cost) do
    cond do
      vitals.qi < cost.qi + 10 -> {:error, "你的体力太低了。\n"}
      vitals.neili < cost.neili -> {:error, "你的内力不够。\n"}
      true -> :ok
    end
  end

  # 柳心剑法练到六十层自动领悟「柳浪闻莺」（简化王师父授艺的 gongxian 门槛）
  defp maybe_unlock_perform("liuxin-jian", stats) do
    unlock_level = Kantele.Combat.Skills.LiuxinJian.perform_unlock_level()

    if Stats.skill(stats, "liuxin-jian") >= unlock_level and
         not Stats.perform_known?(stats, "liuxin-jian/liu") do
      stats = Stats.learn_perform(stats, "liuxin-jian/liu")

      {stats,
       "剑意涌动之间，你领悟了绝招「柳浪闻莺」！（perform liuxin-jian.liu）\n"}
    else
      {stats, ""}
    end
  end

  defp maybe_unlock_perform(_skill_id, stats), do: {stats, ""}

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  defp skill_title("liuxin-jian"), do: "柳心剑法"
  defp skill_title("liuxi-neigong"), do: "柳溪内功"
  defp skill_title(other), do: other
end

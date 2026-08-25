defmodule Kantele.Character.LearnCommand do
  @moduledoc """
  学习命令：`learn <技能> <师父>`

  流程：向房间发 `skills/learn`，房间找到师父 NPC 后转发
  `skills/teach`；由师父侧校验门槛并回执 `skills/learn-result`。
  """

  use Kalevala.Character.Command

  def run(conn, params) do
    # 房间上下文中的角色是 Trimmed 版本，学生属性需随事件自带
    conn
    |> event("skills/learn", %{
      skill: params["skill"],
      name: params["name"],
      student_stats: conn.character.meta.stats
    })
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Character.PracticeCommand do
  @moduledoc """
  练习命令：`practice <技能>`（消耗 qi/neili 换等级）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
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
         :ok <- check_vitals(vitals, cost),
         {:ok, stats} <- spend_potential(stats) do
      {stats, _gained?} = Stats.improve_skill(stats, skill_id)
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

  defp check_vitals(vitals, cost) do
    cond do
      vitals.qi < cost.qi + 10 -> {:error, "你的体力太低了。\n"}
      vitals.neili < cost.neili -> {:error, "你的内力不够。\n"}
      true -> :ok
    end
  end

  defp spend_potential(stats) do
    if stats.potential >= 2 do
      {:ok, %{stats | potential: stats.potential - 2}}
    else
      {:error, "你的潜能不足，先去实战中磨练吧。\n"}
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

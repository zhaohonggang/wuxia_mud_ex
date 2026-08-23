defmodule Kantele.Character.SkillsEvent do
  @moduledoc """
  师徒授艺事件

  - `skills/teach`：房间 -> 师父 NPC，校验后回执
  - `skills/learn-result`：师父 -> 学徒，落等级/潜能/绝招解锁
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @learn_cost 2
  @max_teachable_levels 100

  @base_skills ~w(unarmed sword dodge parry force)

  # ---- 师父侧 ----

  def teach(conn, %{data: %{skill: skill, student_stats: student_stats} = data}) do
    character = conn.character
    reply_to = Map.fetch!(data, :reply_to)
    module = Skills.get(skill)
    base_skill? = skill in @base_skills

    cond do
      is_nil(module) and not base_skill? ->
        reply(reply_to, "「#{skill_title(skill)}」？老朽没听说过这门功夫。\n")
        conn

      not teaches?(character.meta.stats, skill) ->
        reply(reply_to, "这一门功夫老夫已不弱于你，没什么可教的了。\n")
        conn

      Stats.skill(character.meta.stats, skill) <= Stats.skill(student_stats, skill) ->
        reply(reply_to, "这一门功夫你已不弱于老夫，没什么可教的了。\n")
        conn

      student_stats.potential < @learn_cost ->
        reply(reply_to, "你的潜能不足，先去实战中磨练磨练吧。\n")
        conn

      base_skill? ->
        grant(reply_to, character, skill)
        conn

      true ->
        case module.valid_learn(student_stats) do
          :ok ->
            grant(reply_to, character, skill)
            conn

          {:error, message} ->
            reply(reply_to, message)
            conn
        end
    end
  end

  defp grant(reply_to, teacher, skill) do
    reply(reply_to, "#{teacher.name}细心指点你#{skill_title(skill)}的要诀。\n")

    send(reply_to, %Kalevala.Event{
      from_pid: self(),
      topic: "skills/learn-result",
      data: %{skill: skill}
    })
  end

  defp teaches?(stats, skill), do: Stats.skill(stats, skill) > 0

  defp reply(pid, message) do
    send(pid, %Kalevala.Event{
      from_pid: self(),
      topic: "skills/learn-result",
      data: %{skill: nil, failure_message: message}
    })
  end

  # ---- 学徒侧 ----

  def learn_result(conn, %{data: %{skill: nil, failure_message: message}}) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  def learn_result(conn, %{data: %{skill: skill}} = event) do
    character = conn.character
    cost = Map.get(event.data, :cost, @learn_cost)

    before_known? = Stats.perform_known?(character.meta.stats, "liuxin-jian/liu")

    stats = %{character.meta.stats | potential: max(character.meta.stats.potential - cost, 0)}
    {stats, _gained?} = Stats.improve_skill(stats, skill)
    stats = maybe_unlock_perform(skill, stats)

    meta =
      character.meta
      |> Map.put(:stats, stats)
      |> Map.put(:combat, character.meta.combat)

    character = %{character | meta: meta}
    Records.save(character)

    extra =
      case not before_known? and Stats.perform_known?(stats, "liuxin-jian/liu") do
        true -> "剑意涌动之间，你领悟了绝招「柳浪闻莺」！（perform liuxin-jian.liu）\n"
        false -> ""
      end

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: "你的#{skill_title(skill)}进步了！#{extra}"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp maybe_unlock_perform("liuxin-jian", stats) do
    unlock_level = Kantele.Combat.Skills.LiuxinJian.perform_unlock_level()

    if Stats.skill(stats, "liuxin-jian") >= unlock_level do
      Stats.learn_perform(stats, "liuxin-jian/liu")
    else
      stats
    end
  end

  defp maybe_unlock_perform(_skill, stats), do: stats

  defp skill_title("liuxin-jian"), do: "柳心剑法"
  defp skill_title("liuxi-neigong"), do: "柳溪内功"
  defp skill_title("sword"), do: "基本剑法"
  defp skill_title("force"), do: "基本内功"
  defp skill_title(other), do: other

  @doc false
  def max_teachable_levels(), do: @max_teachable_levels
end

defmodule Kantele.Character.SkillsEvent do
  @moduledoc """
  师徒授艺事件

  - `skills/teach`：房间 -> 师父 NPC，校验后回执
  - `skills/learn-result`：师父 -> 学徒，落等级/潜能/绝招解锁
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.LearnGate
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @max_teachable_levels 100
  @max_times 100

  @base_skills ~w(unarmed sword dodge parry force)

  # ---- 师父侧 ----

  def teach(conn, %{data: %{skill: skill, student_stats: student_stats} = data}) do
    character = conn.character
    reply_to = Map.fetch!(data, :reply_to)
    times = Map.get(data, :times, 1)
    module = Skills.get(skill)
    base_skill? = skill in @base_skills
    # b2 捆绑门槛：潜能池(b1)/经验门(b4)/内功互斥(b5)，快照判定
    gate = LearnGate.snapshot_gate(student_stats, skill)

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

      gate != :ok ->
        {:error, message} = gate
        reply(reply_to, message)
        conn

      base_skill? ->
        grant(reply_to, character, skill, teachable(times, character.meta.stats, student_stats, skill))
        conn

      true ->
        case module.valid_learn(student_stats) do
          :ok ->
            grant(
              reply_to,
              character,
              skill,
              teachable(times, character.meta.stats, student_stats, skill)
            )

            conn

          {:error, message} ->
            reply(reply_to, message)
            conn
        end
    end
  end

  # 师生差距决定本次最多能授几级（学生侧潜能逐级校验）
  defp teachable(requested, teacher_stats, student_stats, skill) do
    gap = Stats.skill(teacher_stats, skill) - Stats.skill(student_stats, skill)
    max(min(requested, gap), 0)
  end

  defp grant(reply_to, _teacher, _skill, times) when times < 1 do
    reply(reply_to, "这一门功夫你已不弱于老夫，没什么可教的了。\n")
  end

  defp grant(reply_to, teacher, skill, times) do
    text =
      if times > 1 do
        "#{teacher.name}细心指点你#{skill_title(skill)}的要诀，你连听了 #{times} 讲。\n"
      else
        "#{teacher.name}细心指点你#{skill_title(skill)}的要诀。\n"
      end

    reply(reply_to, text)

    send(reply_to, %Kalevala.Event{
      from_pid: self(),
      topic: "skills/learn-result",
      data: %{skill: skill, times: times}
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
    times = Map.get(event.data, :times, 1)

    before_known? = Stats.perform_known?(character.meta.stats, "liuxin-jian/liu")

    vitals0 = character.meta.vitals
    stats0 = character.meta.stats

    {vitals, stats, learned} = learn_levels(vitals0, stats0, skill, times, 0)

    if learned == 0 do
      {:halt, message} = halt_reason(vitals0, stats0, skill)

      conn
      |> render(CommandView, "text", %{text: message})
      |> prompt(CommandView, "prompt", %{})
    else
      stats = maybe_unlock_perform(skill, stats)
      vitals = Kantele.Character.Vitals.recalculate_max_neili(vitals, stats)

      meta =
        character.meta
        |> Map.put(:stats, stats)
        |> Map.put(:vitals, vitals)
        |> Map.put(:combat, character.meta.combat)

      character = %{character | meta: meta}
      Records.save(character)

      extra =
        case not before_known? and Stats.perform_known?(stats, "liuxin-jian/liu") do
          true -> "剑意涌动之间，你领悟了绝招「柳浪闻莺」！（perform liuxin-jian.liu）\n"
          false -> ""
        end

      qty_text = if learned > 1, do: "（×#{learned}）", else: ""
      tail = partial_text(learned, times)

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{
        text: "你的#{skill_title(skill)}进步了！#{qty_text}#{tail}#{extra}"
      })
      |> prompt(CommandView, "prompt", %{})
    end
  end

  # 逐级学习：潜能池(b1)/耗精(b3)/经验门(b4) 任一不过即停，已学部分保留
  defp learn_levels(vitals, stats, _skill, remaining, n) when remaining < 1,
    do: {vitals, stats, n}

  defp learn_levels(vitals, stats, skill, remaining, n) do
    case LearnGate.level_gate(vitals, stats, skill) do
      :ok ->
        {vitals, stats} = LearnGate.pay_level(vitals, stats, skill)
        {stats, _gained?} = Stats.improve_skill(stats, skill)
        learn_levels(vitals, stats, skill, remaining - 1, n + 1)

      {:halt, _message} ->
        {vitals, stats, n}
    end
  end

  # 全部没学成时给出具体原因（与 level_gate 同源）
  defp halt_reason(vitals, stats, skill) do
    case LearnGate.level_gate(vitals, stats, skill) do
      {:halt, message} -> {:halt, message}
      _ -> {:halt, "然而你今天太累了，无法再进行任何学习了。\n"}
    end
  end

  defp partial_text(learned, times) when learned < times and learned > 0,
    do: "\n但是你今天太累了，学习了 #{learned} 次以后只好先停下来。\n"

  defp partial_text(_, _), do: ""

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

  @doc false
  def max_times(), do: @max_times
end

defmodule Kantele.Combat.Skills.Performs.FanliangyiDao.Makearray do
  @moduledoc """
  双剑和壁「makearray」（对照 `kungfu/skill/fanliangyi-dao/makearray.c`）

  组阵：队伍恰 2 人，全队均可满足刀阵门槛后，以
  `n = (两人反两仪刀平均) + 队长技能*5 / (max-min+1)` 为当量、
  attack/defense/damage/armor +n。

  本版降级实现（TODO(migrate)）：
  - 队友只是 `%{id, name, pid}` 引用快照，技能/武器/内力远程不可得；n 以
    `队长技能*6`（等技能下 LPC 公式）代偿，spread 与平均不建模；
  - 队友门槛改由 `Kantele.Character.FanliangyiEvent.array/2` 在自身进程
    复验（可远程满足的项：会刀、>=30、激发 blade、持刀、max_neili>=50、
    未在阵中），不服者静默忽略（LPC 是有文案的 notify_fail）；
  - LPC `array_kill`（队长击杀全体杀）与 `dismiss_array`（队长解散）未建模；
  - LPC `set_temp("no_quit",1)`（组阵期间不可退队）未建模。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Team
  alias Kantele.Combat.Broadcast

  @perform "fanliangyi-dao/makearray"
  @array_key "array/fanliangyi-dao"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, team} <- team(character),
         :ok <- two_members(team),
         {:ok, partner} <- partner(team, character),
         :ok <- mapped(stats),
         :ok <- weapon(combat),
         :ok <- level(stats),
         :ok <- neili(character),
         :ok <- not_in_array(combat),
         :ok <- partner_alive(partner) do
      n = array_level(stats)

      buff =
        %Combat.Buff{
          key: @array_key,
          applies: %{attack: -n, defense: -n, damage: -n, armor: -n}
        }

      combat =
        combat
        |> Combat.apply_temp(%{attack: n, defense: n, damage: n, armor: n})
        |> Combat.add_buff(buff)

      character = %{character | meta: %{character.meta | combat: combat}}

      send(partner.pid, %Event{
        from_pid: self(),
        topic: @array_key,
        data: %{leader: ref(character), n: n}
      })

      conn
      |> put_character(character)
      |> Broadcast.publish(
        "$N率领$n站定两仪方位，顿时两人之间显得浑然天成、毫无破绽。\n",
        n1: character.name,
        n2: partner.name
      )
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  defp team(character) do
    case Map.get(character.meta, :team) do
      nil -> {:error, "你还没有加入任何队伍。\n"}
      team -> {:ok, team}
    end
  end

  defp two_members(team) do
    if Team.size(team) == 2,
      do: :ok,
      else: {:error, "反两仪刀共需两人，少一个多一个都不行。\n"}
  end

  defp partner(team, character) do
    case Enum.find(team.members, &(&1.id != character.id)) do
      nil -> {:error, "你想和谁同使反两仪刀？\n"}
      partner -> {:ok, partner}
    end
  end

  defp partner_alive(partner) do
    if Process.alive?(partner.pid),
      do: :ok,
      else: {:error, "你想和谁同使反两仪刀？\n"}
  end

  defp mapped(stats) do
    if Stats.mapped(stats, "blade") == "fanliangyi-dao",
      do: :ok,
      else: {:error, "你必须使用反两仪刀法。\n"}
  end

  defp weapon(combat) do
    if match?(%{skill_type: "blade"}, Combat.weapon(combat)),
      do: :ok,
      else: {:error, "你必须拿把刀做武器。\n"}
  end

  defp level(stats) do
    if Stats.skill(stats, "fanliangyi-dao") < 30,
      do: {:error, "你的反两仪刀法还不够熟练。\n"},
      else: :ok
  end

  defp neili(character) do
    if character.meta.vitals.max_neili < 50,
      do: {:error, "你的内力不够。\n"},
      else: :ok
  end

  defp not_in_array(combat) do
    if Combat.buff_active?(combat, @array_key),
      do: {:error, "他已经在刀阵中了。\n"},
      else: :ok
  end

  defp array_level(stats), do: Stats.skill(stats, "fanliangyi-dao") * 6

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
defmodule Kantele.Combat.Skills.Performs.FanliangyiDao.Makearray do
  @moduledoc """
  双剑和壁「makearray」（对照 `kungfu/skill/fanliangyi-dao/makearray.c`）

  组阵：队伍恰 2 人，全队均可满足刀阵门槛后，以
  `n = (两人反两仪刀平均) + 队长技能*5 / (max-min+1)` 为当量、
  attack/defense/damage/armor +n。

  本版降级实现（TODO(migrate)）：
  - 队友只是 `%{id, name, pid, room_id}` 引用快照，技能/武器/内力远程不可得；
    各门槛以**队长自身**代检（`.c` 的 `ob->query(...)` 对队长同样成立），
    文案沿用 `.c` 的 `<名字> + 后缀` 拆段形式；
  - 队友门槛改由 `Kantele.Character.FanliangyiEvent.array/2` 在自身进程
    复验，不服者静默忽略；
  - LPC `array_kill`（队长击杀全体杀）未建模；
  - LPC `dismiss_array`（队长解散）未建模，仅保留其文案
    （`dismiss_message/0`）；
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
         {:ok, team} <- two_members(character),
         {:ok, partner} <- partner(team, character),
         :ok <- not_in_array(combat),
         :ok <- same_room(character, partner),
         :ok <- knows_skill(character),
         :ok <- not_ghost(),
         :ok <- max_neili(character),
         :ok <- weapon(character, combat),
         :ok <- level(character),
         :ok <- mapped(character) do
      n = array_level(stats)

      buff = %Combat.Buff{
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

  # LPC: if (sizeof(member) != 2)
  defp two_members(character) do
    team = Map.get(character.meta, :team)
    msg = "反两仪刀共需两人，少一个多一个都不行。\n"

    if team != nil and Team.size(team) == 2 do
      {:ok, team}
    else
      {:error, msg}
    end
  end

  # LPC: if (!ob || !living(ob) || !ob->is_character())
  defp partner(team, character) do
    msg = "你想和谁同使反两仪刀？\n"

    case Enum.find(team.members, &(&1.id != character.id)) do
      nil ->
        {:error, msg}

      partner ->
        if Process.alive?(partner.pid), do: {:ok, partner}, else: {:error, msg}
    end
  end

  # LPC: if (ob->query_temp("array/name"))
  defp not_in_array(combat) do
    if Combat.buff_active?(combat, @array_key),
      do: {:error, "他已经在刀阵中了。\n"},
      else: :ok
  end

  # LPC: if (environment(leader) != environment(ob))
  defp same_room(character, partner) do
    if partner.room_id == character.room_id,
      do: :ok,
      else: {:error, "人数不够两人。\n"}
  end

  # LPC: if (!ob->query_skill("fanliangyi-dao", 1))
  defp knows_skill(character) do
    if Stats.skill(character.meta.stats, "fanliangyi-dao") <= 0,
      do: {:error, character.name <> "还不会反两仪刀法。\n"},
      else: :ok
  end

  # LPC: if (ob->is_ghost()) —— 本引擎无 ghost 概念，保留文案。
  defp not_ghost do
    _ = "只有阳间的人才能组刀阵。\n"
    :ok
  end

  # LPC: if ((int)ob->query("max_neili") < 50)
  defp max_neili(character) do
    if character.meta.vitals.max_neili < 50,
      do: {:error, character.name <> "的内力不够。\n"},
      else: :ok
  end

  # LPC: if (!(weapon = ob->query_temp("weapon")) || weapon->query("skill_type") != "blade")
  defp weapon(character, combat) do
    if match?(%{skill_type: "blade"}, Combat.weapon(combat)),
      do: :ok,
      else: {:error, character.name <> "必须拿把刀做武器。\n"}
  end

  # LPC: if ((int)ob->query_skill("fanliangyi-dao", 1) < 30)
  defp level(character) do
    if Stats.skill(character.meta.stats, "fanliangyi-dao") < 30,
      do: {:error, character.name <> "的反两仪刀法还不够熟练。\n"},
      else: :ok
  end

  # LPC: if ((string)ob->query_skill_mapped("blade") != "fanliangyi-dao")
  defp mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "fanliangyi-dao",
      do: :ok,
      else: {:error, character.name <> "必须使用反两仪刀法。\n"}
  end

  defp array_level(stats), do: Stats.skill(stats, "fanliangyi-dao") * 6

  @doc """
  LPC `dismiss_array/1` 的文案（`tell_object(ob, "刀阵解散了\\n")`）。
  本引擎未建模解散流程，仅保留文案以对齐 `.c`。
  """
  def dismiss_message, do: "刀阵解散了\n"

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end

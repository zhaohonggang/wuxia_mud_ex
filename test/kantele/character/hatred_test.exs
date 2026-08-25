defmodule Kantele.Character.HatredTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEngageAction
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.NPCConfig
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Fighter

  @recv_timeout 3000

  defp boar(opts \\ []) do
    stats =
      Stats.new()
      |> struct(
        Keyword.get(opts, :stats,
          str: 16,
          dex: 20,
          con: 14,
          int: 6,
          combat_exp: 500,
          skills: %{"unarmed" => 20}
        )
      )

    vitals =
      Vitals.new()
      |> struct(Keyword.get(opts, :vitals, qi: 200, max_qi: 200, jing: 100, max_jing: 100))

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "npc-boar"),
      name: "野猪",
      pid: self(),
      room_id: "test:room",
      meta: %NonPlayerMeta{
        vitals: vitals,
        stats: stats,
        combat_config: %NPCConfig{spawn_room_id: "test:spawn"},
        combat: Combat.new()
      }
    }
  end

  defp player(id \\ "player-1"),
    do: %Kalevala.Character{
      id: id,
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Combat.new()
      }
    }

  defp attacker_ref(p),
    do: %{id: p.id, pid: p.pid, name: p.name, room_id: p.room_id}

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "被打后记入 attacked_by（内存态仇恨）" do
    boar = boar()
    attacker = boar(id: "npc-2", name: "山猪")

    conn =
      CombatEvent.incoming(build_conn(boar), %{
        topic: "combat/incoming",
        data: %{attacker: attacker_ref(attacker), fighter: Fighter.from_character(attacker)}
      })

    updated = conn.private.update_character || conn.character
    assert Combat.attacked_by_ids(updated.meta.combat) == [attacker.id]
  end

  test "engage 动作把仇恨名单带进 combat/aggressive 事件" do
    boar = boar()
    p = player()
    boar = put_attacked_by(boar, p.id)

    conn = CombatEngageAction.run(build_conn(boar), %{})

    p_id = p.id
    assert [%Event{topic: "combat/aggressive", data: %{hated_ids: [^p_id]}}] = conn.events
  end

  defp put_attacked_by(character, id) do
    combat = Combat.record_attacked_by(character.meta.combat, id)
    %{character | meta: Map.put(character.meta, :combat, combat)}
  end
end

defmodule Kantele.Combat.FlowTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.NPCConfig
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @recv_timeout 3000

  defp player(opts \\ []) do
    stats =
      Stats.new()
      |> struct(
        Keyword.get(opts, :stats,
          str: 20,
          dex: 20,
          con: 20,
          int: 20,
          skills: %{"sword" => 60, "force" => 60, "dodge" => 60, "parry" => 60},
          mapped: %{"sword" => "liuxin-jian"},
          potential: 100
        )
      )

    combat =
      Combat.new()
      |> Combat.equip(:weapon, %{name: "长剑 Changjian", skill_type: "sword", damage: 22})

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: combat
      }
    }
  end

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
          skills: %{"unarmed" => 20, "dodge" => 1, "parry" => 1}
        )
      )

    vitals =
      Vitals.new()
      |> struct(Keyword.get(opts, :vitals, qi: 200, max_qi: 200, jing: 100, max_jing: 100))

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "npc-boar"),
      name: Keyword.get(opts, :name, "野猪"),
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

  defp ref(character), do: %{id: character.id, pid: character.pid, name: character.name}

  defp engage(conn, _receiver, initiator) do
    CombatEvent.start(conn, %{
      topic: "combat/start",
      data: %{enemy: ref(initiator), initiator_id: initiator.id}
    })
  end

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp current_vitals(character), do: character.meta.vitals

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn change ->
      match?({:publish, _, %Event{topic: Kalevala.Event.Message}, _, _}, change)
    end)
    |> Enum.map(fn {:publish, _channel, event, _opts, _error} -> event.data.text end)
    |> Enum.join("")
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "start：双方互加敌人并调度心跳，非发起方收到警告" do
    a = player()
    b = boar()

    conn_a = engage(build_conn(a), a, b)
    a1 = current_character(conn_a)

    # tick 经 foreman 自投递到测试进程（角色 pid = self()）
    assert_receive %Event{topic: "combat/tick"}, @recv_timeout

    assert Combat.enemy?(a1.meta.combat, b.id)

    conn_b = engage(build_conn(b), b, a)
    assert Combat.enemy?(current_character(conn_b).meta.combat, a.id)
    assert output_text(conn_b) =~ "想杀死你"
  end

  test "tick：攻击者向对方进程发送 incoming 快照并重排心跳" do
    a = player()
    b = boar()

    conn = engage(build_conn(a), a, b)
    a1 = current_character(conn)

    CombatEvent.tick(build_conn(a1), %{topic: "combat/tick"})

    assert_receive %Event{topic: "combat/incoming", data: data}, @recv_timeout
    assert data.attacker.id == a.id
    assert data.fighter.name == a.name
    assert data.fighter.attack_skill == "sword"

    tick_conn = build_conn(a1)
    CombatEvent.tick(tick_conn, %{topic: "combat/tick"})

    assert_receive %Event{topic: "combat/tick"}, @recv_timeout
  end

  test "incoming：防守方结算伤害、广播战况并扣血" do
    a = player()
    initial_boar = boar()

    {all_text, _moved, _conn, final_boar, rounds} =
      exchange_rounds(a, initial_boar, fn _ch -> false end, 40)

    assert all_text =~ "张三"
    assert rounds >= 1

    assert current_vitals(final_boar).qi < current_vitals(final_boar).max_qi or all_text =~ "结果"
  end

  test "death：气血归零触发尸体文案、奖励通知与重生传送" do
    a = player()
    initial_boar = boar(vitals: [qi: 8, max_qi: 150])

    {_all_text, moved, conn, _final_boar, rounds} =
      exchange_rounds(a, initial_boar, fn _ch -> false end, 40)

    # 击杀奖励消息是死亡结算的权威信号
    assert_receive %Event{topic: "combat/enemy-died", data: data}, @recv_timeout
    assert data.exp >= 5
    assert data.potential >= 2
    assert rounds >= 1

    # NPC 死亡走虚空停尸 + 定时重生（Movement :to 事件入队）
    assert moved
  end

  # victim 持续承受 attacker 的 incoming，累积全部战况文案
  defp exchange_rounds(attacker, victim, pred, max_rounds) do
    attacker_conn = engage(build_conn(attacker), attacker, victim)
    attacker1 = current_character(attacker_conn)

    victim_conn = engage(build_conn(victim), victim, attacker)
    victim1 = current_character(victim_conn)

    do_rounds(attacker1, victim1, nil, 0, pred, max_rounds, [], false)
  end

  defp do_rounds(_attacker, victim, last_conn, n, _pred, max, acc, moved)
       when n >= max do
    {IO.iodata_to_binary(Enum.reverse(acc)), moved, last_conn || %Kalevala.Character.Conn{}, victim, n}
  end

  defp do_rounds(attacker, victim, last_conn, n, pred, max, acc, moved) do
    f = Kantele.Combat.Fighter.from_character(attacker)

    victim_conn =
      CombatEvent.incoming(build_conn(victim), %{
        topic: "combat/incoming",
        data: %{attacker: ref(attacker), fighter: f}
      })

    new_victim = current_character(victim_conn)
    acc = [published_text(victim_conn) | acc]

    moved =
      moved or
        Enum.any?(victim_conn.events, fn
          %Event{topic: Kalevala.Event.Movement, data: %{direction: :to}} -> true
          _ -> false
        end)

    if pred.(new_victim) do
      {IO.iodata_to_binary(Enum.reverse(acc)), victim_conn, new_victim, n + 1}
    else
      do_rounds(attacker, new_victim, victim_conn, n + 1, pred, max, acc, moved)
    end
  end
end

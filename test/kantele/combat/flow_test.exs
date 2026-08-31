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
  alias Kantele.Quest

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

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

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

  test "death：气血归零触发尸体文案、奖励通知与原地装死" do
    a = player()
    initial_boar = boar(vitals: [qi: 8, max_qi: 150])

    {_all_text, conn, final_boar, rounds} =
      exchange_rounds(a, initial_boar, fn ch -> ch.status =~ "尸体" end, 40)

    # 击杀奖励消息是死亡结算的权威信号
    assert_receive %Event{topic: "combat/enemy-died", data: data}, @recv_timeout
    assert data.exp >= 5
    assert data.potential >= 2
    assert rounds >= 1

    # NPC 原地装死：状态文案变为尸体，dead 标志停掉大脑/心跳
    assert final_boar.meta.combat.dead
    assert final_boar.status =~ "尸体"
  end

  test "被动挨打：未入战的防守方自动加敌人并启动心跳" do
    a = player()
    b = boar()

    # b 从未收到 combat/start（复活窗口期残留心跳等单方面攻击）
    refute Combat.enemy?(b.meta.combat, a.id)

    f = Kantele.Combat.Fighter.from_character(a)

    conn =
      CombatEvent.incoming(build_conn(b), %{
        topic: "combat/incoming",
        data: %{attacker: ref(a), fighter: f}
      })

    assert Combat.enemy?(current_character(conn).meta.combat, a.id)
    assert_receive %Event{topic: "combat/tick"}, @recv_timeout
  end

  test "单方面战斗致死：击杀者仍收到结算奖励" do
    a = player()
    initial_boar = boar(vitals: [qi: 8, max_qi: 150])

    # 不走房间 engage，直接持续 incoming（复现复活窗口期单方面挨打）
    final_boar = one_sided_beating(a, initial_boar, 40)

    assert final_boar.meta.combat.dead

    assert_receive %Event{topic: "combat/enemy-died", data: data}, @recv_timeout
    assert data.exp >= 5
    assert data.potential >= 2
  end

  test "respawn：从 base_* 还原配置气血而非玩家默认值" do
    boar1 =
      boar(
        vitals: [
          qi: 0,
          max_qi: 27,
          base_qi: 80,
          jing: 60,
          max_jing: 60,
          base_jing: 60,
          neili: 0,
          max_neili: 0,
          base_neili: 0
        ]
      )

    conn = CombatEvent.respawn(build_conn(boar1), %{})
    vitals = current_vitals(current_character(conn))

    assert vitals.qi == 80
    assert vitals.max_qi == 80
  end

  # 防守方从未 engage，只承受 attacker 的 incoming 直到死亡
  defp one_sided_beating(attacker, victim, max_rounds) do
    f = Kantele.Combat.Fighter.from_character(attacker)

    do_one_sided(attacker, f, victim, max_rounds)
  end

  defp do_one_sided(_attacker, _f, victim, 0), do: victim

  defp do_one_sided(attacker, f, victim, n) do
    if victim.meta.combat.dead or current_vitals(victim).qi <= 0 do
      victim
    else
      victim_conn =
        CombatEvent.incoming(build_conn(victim), %{
          topic: "combat/incoming",
          data: %{attacker: ref(attacker), fighter: f}
        })

      do_one_sided(attacker, f, current_character(victim_conn), n - 1)
    end
  end

  describe "Fighter 快照有效等级（LPC query_skill）" do
    test "enable 映射后判定等级 = 基本 + 特技" do
      a =
        player(
          stats: [
            skills: %{
              "sword" => 30,
              "parry" => 10,
              "dodge" => 60,
              "force" => 20,
              "liuxin-jian" => 40
            },
            mapped: %{"sword" => "liuxin-jian", "parry" => "liuxin-jian"}
          ]
        )

      f = Kantele.Combat.Fighter.from_character(a)

      assert f.skills["sword"] == 70
      assert f.skills["parry"] == 50
      assert f.skills["dodge"] == 60
    end

    test "未映射的 NPC 等级保持原样" do
      f = Kantele.Combat.Fighter.from_character(boar())

      assert f.skills["unarmed"] == 20
      assert f.skills["dodge"] == 1
      assert f.mapped == %{}
    end

    test "有效等级放大攻击当量" do
      plain = player(stats: [skills: %{"unarmed" => 60, "dodge" => 60}, mapped: %{}])

      mapped_sword =
        player(
          stats: [
            skills: %{"sword" => 30, "liuxin-jian" => 40},
            mapped: %{"sword" => "liuxin-jian"}
          ]
        )

      f1 = Kantele.Combat.Fighter.from_character(plain)
      f2 = Kantele.Combat.Fighter.from_character(mapped_sword)

      ap1 = Kantele.Combat.Engine.skill_power(f1, f1.attack_skill, :attack)
      ap2 = Kantele.Combat.Engine.skill_power(f2, f2.attack_skill, :attack)

      assert ap2 > ap1
    end
  end

  describe "击杀结算" do
    test "铜钱/门派贡献/掉落随 enemy-died 入账（读内层 data）" do
      a = player()

      conn =
        CombatEvent.enemy_died(build_conn(a), %{
          topic: "combat/enemy-died",
          data: %{
            id: "npc-x",
            exp: 20,
            potential: 10,
            coins: 7,
            gongxian: 1,
            drops: ["liuxi:yupai"]
          }
        })

      c = current_character(conn)

      assert c.meta.stats.combat_exp == 1000 + 20
      assert c.meta.stats.potential == 100 + 10
      assert c.meta.stats.gongxian == 0
      assert c.meta.coins == 7
      assert Enum.any?(c.inventory, &(&1.item_id == "liuxi:yupai"))
    end

    test "拜师后门派贡献累积" do
      a = player()
      a = put_in(a.meta.family, %{name: "柳溪派"})

      conn =
        CombatEvent.enemy_died(build_conn(a), %{
          topic: "combat/enemy-died",
          data: %{id: "npc-x", exp: 5, potential: 2, gongxian: 3}
        })

      assert current_character(conn).meta.stats.gongxian == 3
    end

    test "击杀计入在办任务的杀怪进度（裸 key 匹配）" do
      a = player()

      {:ok, quests} = Quest.set_todo(Quest.new(), %{file: "song-yupai", kill: ["yezhu"]})

      a = %{a | meta: PlayerMeta.put_quests(a.meta, quests)}

      conn =
        CombatEvent.enemy_died(build_conn(a), %{
          topic: "combat/enemy-died",
          data: %{id: "liuxi:yezhu", exp: 5, potential: 2}
        })

      task = current_character(conn).meta |> PlayerMeta.quests() |> Quest.get_todo("song-yupai")
      assert task.killed["yezhu"] == 1
    end

    test "与任务无关的击杀不影响进度" do
      a = player()

      {:ok, quests} = Quest.set_todo(Quest.new(), %{file: "song-yupai", kill: ["yezhu"]})

      a = %{a | meta: PlayerMeta.put_quests(a.meta, quests)}

      conn =
        CombatEvent.enemy_died(build_conn(a), %{
          topic: "combat/enemy-died",
          data: %{id: "liuxi:lang", exp: 5, potential: 2}
        })

      task = current_character(conn).meta |> PlayerMeta.quests() |> Quest.get_todo("song-yupai")
      assert task.killed["yezhu"] == 0
    end
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
    {IO.iodata_to_binary(Enum.reverse(acc)), moved, last_conn || %Kalevala.Character.Conn{},
     victim, n}
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

defmodule Kantele.Character.CombatEvent do
  @moduledoc """
  战斗事件处理（玩家与 NPC 共用，挂在两个 Events 路由上）

  事件一览：

  | topic                   | 方向              | 说明 |
  |-------------------------|-------------------|------|
  | `combat/start`          | 房间 -> 双方       | 加入敌人并开始心跳 |
  | `combat/tick`           | 自身定时          | 心跳：busy--、清理敌人、发出 incoming |
  | `combat/incoming`       | 攻击方 -> 防守方   | 防守方以自身完整状态结算伤害 |
  | `combat/enemy-died`     | 防守方 -> 击杀者   | 清理敌人并发放奖励 |
  | `combat/enemy-left`     | 移动方 -> 敌人     | 对方离开房间/退场，移除敌人 |
  | `combat/halt`           | 停手方 -> 敌人     | 相互停手 |
  | `combat/yield`          | 陪练方 -> 对手     | 点到即止（no_kill NPC）|
  | `combat/buff-expire`    | 自身定时          | 绝招/运功到期回收加成 |
  | `combat/respawn`        | 自身定时          | NPC 尸体回出生点重生 |
  | `vitals/regen`          | 自身定时          | 自然回复循环 |

  心跳模型对应 LPC `feature/attack.c#heart_beat`：每个参战角色经 foreman 的
  定时自投递 1s 一轮；状态全部存放在自身 foreman 的 character.meta 中。
  攻击者只出招（发快照），防守方以完整状态结算——对应 LPC receive_damage
  在受害者对象上执行，同时规避房间上下文中角色元数据被 Trimmed 的限制。
  """

  use Kalevala.Character.Event

  require Logger

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Messages
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.Character.Vitals

  @tick_interval 1000
  @regen_interval 15_000
  @respawn_delay 60_000
  @nether_room "liuxi:rooms:nether"

  # ---- 自我定时：直接 Process.send_after，绕开房间路由 ----

  defp schedule_self(topic, data, ms) do
    Process.send_after(
      self(),
      %Event{from_pid: self(), topic: topic, data: data},
      ms
    )
  end

  # ---- 频道消息渲染 ----

  def interested?(event) do
    event.data.type == "combat" && match?("rooms:" <> _, event.data.channel_name)
  end

  def echo(conn, event) do
    conn
    |> assign(:text, event.data.text)
    |> render(CommandView, "combat-text")
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 开战 ----

  def start(conn, %{data: %{enemy: enemy, initiator_id: initiator_id}}) do
    character = conn.character

    if dead?(character) or enemy.id == character.id do
      conn
    else
      {combat, new_fight?} = Combat.add_enemy(character.meta.combat, enemy)
      character = put_combat(character, combat)

      conn =
        case initiator_id == character.id do
          true ->
            Broadcast.publish(conn, "$N对著$n一声大喝，蓦地直冲过来！\n",
              n1: character.name,
              n2: enemy.name
            )

          false ->
            render(conn, CommandView, "under-attack", %{name: enemy.name})
        end

      conn = put_character(conn, character)

      if new_fight? do
        schedule_self("combat/tick", %{}, @tick_interval)
      end

      conn
    end
  end

  # ---- 心跳 ----

  def tick(conn, _event) do
    character = conn.character
    combat = character.meta.combat

    cond do
      dead?(character) ->
        conn

      true ->
        combat = clean_enemies(combat)
        combat = decrement_busy(combat)

        case combat.enemies do
          [] ->
            put_character(conn, put_combat(character, combat))

          enemies ->
            enemy = Enum.random(enemies)
            strike(conn, character, combat, enemy)
        end
    end
  end

  # 攻击方只负责出招：把自己的快照发给对方，由对方以完整状态结算
  defp strike(conn, character, combat, enemy) do
    vitals = character.meta.vitals

    jiali_paid =
      if combat.jiali > 0 and vitals.neili > combat.jiali do
        combat.jiali
      else
        0
      end

    conn =
      case jiali_paid > 0 do
        true ->
          vitals = %{vitals | neili: vitals.neili - jiali_paid}
          put_character(conn, put_vitals(character, vitals))

        false ->
          conn
      end

    attacker_fighter = Fighter.from_character(character)

    send(
      enemy.pid,
      %Event{
        from_pid: self(),
        topic: "combat/incoming",
        data: %{
          attacker: ref(character),
          fighter: attacker_fighter,
          jiali_paid: jiali_paid
        }
      }
    )

    schedule_self("combat/tick", %{}, @tick_interval)

    conn
  end

  # ---- 受击结算（防守方以自身完整状态执行）----

  def incoming(conn, %{data: %{attacker: attacker, fighter: attacker_fighter} = data}) do
    character = conn.character

    cond do
      dead?(character) or not Process.alive?(attacker.pid) ->
        notify_left(conn, character, attacker)

      true ->
        resolve_incoming(conn, character, attacker, attacker_fighter, data)
    end
  end

  defp resolve_incoming(conn, character, attacker, attacker_fighter, _data) do
    victim_fighter = Fighter.from_character(character)
    round = Engine.attack_round(attacker_fighter, victim_fighter)

    bindings = [
      n1: attacker.name,
      n2: character.name,
      limb: round.limb,
      weapon: attacker_fighter.weapon_name || "拳头"
    ]

    text = round.segments |> IO.iodata_to_binary() |> Messages.interpolate(bindings)
    conn = Broadcast.publish(conn, text)

    case {round.outcome, round.damage > 0 or round.wounded > 0} do
      {:hit, true} ->
        apply_hit(conn, character, attacker, %{
          damage: round.damage,
          wounded: round.wounded
        })

      _ ->
        conn
    end
  end

  defp apply_hit(conn, character, attacker, data) do
    damage = Map.get(data, :damage, 0)
    wounded = Map.get(data, :wounded, 0)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, wounded)

    character = put_vitals(character, vitals)

    ratio = div(vitals.qi * 100, max(vitals.max_qi, 1))
    status_text = Messages.eff_status_msg(ratio)

    conn =
      conn
      |> Broadcast.publish("( $n#{status_text})\n", n2: character.name)
      |> put_character(character)

    config = combat_config(character)

    cond do
      vitals.qi <= 0 ->
        die(conn, character, attacker)

      Map.get(config, :no_kill, false) and vitals.qi * 3 <= vitals.max_qi ->
        yield_to(conn, character, attacker)

      true ->
        conn
    end
  end

  # ---- 死亡与重生 ----

  defp die(conn, character, killer) do
    conn = Broadcast.publish(conn, Messages.death_msg(), n1: character.name)

    reward = reward_for(character.meta.stats)

    Enum.each(character.meta.combat.enemies, fn enemy ->
      base = %{id: character.id, name: character.name}

      {topic, data} =
        if enemy.id == killer.id do
          {"combat/enemy-died", Map.merge(base, reward)}
        else
          {"combat/enemy-left", base}
        end

      send(enemy.pid, %Event{from_pid: self(), topic: topic, data: data})
    end)

    character =
      character
      |> put_vitals(Vitals.new())
      |> put_combat(Combat.new())

    conn = put_character(conn, character)

    destination = death_destination(character)
    conn = Teleport.teleport(conn, destination)

    case npc?(character) do
      true ->
        schedule_self("combat/respawn", %{}, @respawn_delay)
        conn

      false ->
        render(conn, CommandView, "revive", %{})
    end
  end

  defp npc?(%{meta: %{combat_config: %{spawn_room_id: spawn_room_id}}})
       when is_binary(spawn_room_id),
       do: true

  defp npc?(_), do: false

  defp death_destination(%{meta: %{combat_config: %{spawn_room_id: id}}})
       when is_binary(id),
       do: @nether_room

  defp death_destination(_character), do: starting_room_id()

  def respawn(conn, _event) do
    character = conn.character

    case combat_config(character).spawn_room_id do
      nil ->
        conn

      room_id ->
        character =
          character
          |> put_vitals(Vitals.new())
          |> put_combat(Combat.new())

        conn
        |> put_character(character)
        |> Broadcast.publish(Messages.revive_msg(), n1: character.name)
        |> Teleport.teleport(room_id)
    end
  end

  # ---- 敌人变化 ----

  def enemy_died(conn, %{data: %{id: id, exp: exp, potential: potential}}) do
    character = conn.character
    combat = Combat.remove_enemy(character.meta.combat, id)

    stats = %{
      character.meta.stats
      | combat_exp: character.meta.stats.combat_exp + (exp || 0),
        potential: character.meta.stats.potential + (potential || 0)
    }

    character =
      character
      |> put_stats(stats)
      |> put_combat(combat)

    Kantele.Character.Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "kill-reward", %{exp: exp, potential: potential})
    |> prompt(CommandView, "prompt", %{})
  end

  def enemy_left(conn, %{data: %{id: id}}) do
    drop_enemy(conn, id)
  end

  def halt(conn, %{data: %{id: id}}) do
    drop_enemy(conn, id)
  end

  defp drop_enemy(conn, id) do
    character = conn.character
    combat = Combat.remove_enemy(character.meta.combat, id)

    conn
    |> put_character(put_combat(character, combat))
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 点到即止 ----

  defp yield_to(conn, character, attacker) do
    conn
    |> Broadcast.publish(Messages.winner_msg(), n1: attacker.name, n2: character.name)
    |> send_event(attacker.pid, "combat/yield", %{id: character.id, name: character.name})
  end

  def yield(conn, %{data: %{id: id}}) do
    drop_enemy(conn, id)
  end

  # ---- buff 到期 ----

  def buff_expire(conn, %{data: %{key: key} = data}) do
    character = conn.character
    applies = Map.get(data, :applies, %{})

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.remove_buff(key)

    character = put_combat(character, combat)

    conn =
      case Map.get(data, :message) do
        nil -> conn
        message -> render(conn, CommandView, "text", %{text: message})
      end

    conn
    |> put_character(character)
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 自然回复 ----

  @doc "自然回复循环：受伤时每 #{@regen_interval}ms 自愈一次，满血自动停止"
  def regen(conn, _event) do
    character = conn.character
    vitals = character.meta.vitals
    fighting? = Combat.fighting?(character.meta.combat)

    vitals = Vitals.regenerate(vitals, character.meta.stats, fighting?)

    conn = put_character(conn, put_vitals(character, vitals))

    if injured?(vitals) do
      schedule_self("vitals/regen", %{}, @regen_interval)
    end

    conn
  end

  defp injured?(%Vitals{} = vitals) do
    vitals.qi < vitals.max_qi or vitals.jing < vitals.max_jing or
      vitals.neili < vitals.max_neili
  end

  @doc "启动自然回复循环（登录/NPC 生成时调用）"
  def kick_regen(), do: schedule_self("vitals/regen", %{}, @regen_interval)

  # ---- 工具 ----

  defp clean_enemies(combat) do
    %{combat | enemies: Enum.filter(combat.enemies, &Process.alive?(&1.pid))}
  end

  defp decrement_busy(%Combat{busy: busy} = combat) when busy > 0,
    do: %{combat | busy: busy - 1}

  defp decrement_busy(combat), do: combat

  defp notify_left(conn, character, enemy) do
    send(enemy.pid, %Event{
      from_pid: self(),
      topic: "combat/enemy-left",
      data: %{id: character.id}
    })

    conn
  end

  defp dead?(%{meta: %{combat: %Combat{dead: dead}}}), do: dead
  defp dead?(_), do: false

  defp ref(character), do: %{id: character.id, pid: character.pid, name: character.name}

  defp combat_config(%{meta: %{combat_config: %{} = config}}), do: config
  defp combat_config(_), do: %{}

  defp starting_room_id() do
    Kantele.Config.get([:player, :starting_room_id])
    |> Kantele.World.dereference()
  end

  defp reward_for(victim_stats) do
    exp = max(div(victim_stats.combat_exp, 10), 5)
    %{exp: exp, potential: max(div(exp, 2), 2)}
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp put_vitals(character, vitals),
    do: %{character | meta: Map.put(character.meta, :vitals, vitals)}

  defp put_stats(character, stats),
    do: %{character | meta: Map.put(character.meta, :stats, stats)}

  defp send_event(conn, pid, topic, data) do
    send(pid, %Event{from_pid: self(), topic: topic, data: data})
    conn
  end
end

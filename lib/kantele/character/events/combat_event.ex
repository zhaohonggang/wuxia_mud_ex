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
  alias Kantele.Character.Combat.StatusTracker
  alias Kantele.Character.CharacterView
  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.Character.Vitals

  @tick_interval 1000
  @regen_interval 15_000
  @default_respawn_delay 30_000

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

    cond do
      enemy.id == character.id ->
        conn

      dead?(character) ->
        # 我已是尸体：显式拒绝，让攻击者把我从敌人列表移除
        send(
          enemy.pid,
          %Event{
            from_pid: self(),
            topic: "combat/reject-dead",
            data: %{id: character.id, name: character.name}
          }
        )

        conn

      true ->
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
            # 只攻击仍在同一房间的敌人；异房的残留引用直接清除并通知对方
            {same_room, gone} =
              Enum.split_with(enemies, &(Map.get(&1, :room_id) == character.room_id))

            Enum.each(gone, fn gone_enemy ->
              if Process.alive?(gone_enemy.pid) do
                send(gone_enemy.pid, %Event{
                  from_pid: self(),
                  topic: "combat/enemy-left",
                  data: %{id: character.id}
                })
              end
            end)

            character = put_combat(character, %{combat | enemies: same_room})

            Enum.each(gone, fn gone_enemy ->
              if Process.alive?(gone_enemy.pid) do
                send(gone_enemy.pid, %Event{
                  from_pid: self(),
                  topic: "combat/enemy-left",
                  data: %{id: character.id}
                })
              end
            end)

            case same_room do
              [] ->
                put_character(conn, character)

              enemies ->
                enemy = Enum.random(enemies)
                strike(conn, character, character.meta.combat, enemy)
            end
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

      # 攻击者已不在同一房间（死亡重生/逃跑后的残留心跳）：忽略并移除
      Map.get(attacker, :room_id) != character.room_id ->
        notify_left(conn, character, attacker)

      true ->
        resolve_incoming(conn, character, attacker, attacker_fighter, data)
    end
  end

  defp resolve_incoming(conn, character, attacker, attacker_fighter, _data) do
    # 记仇（A9/P11）：把打过我的人记入 attacked_by，aggressive 重开战时优先寻仇
    combat = Kantele.Character.Combat.record_attacked_by(character.meta.combat, attacker.id)
    character = put_combat(character, combat)
    conn = put_character(conn, character)

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
      |> render(CharacterView, "vitals")

    config = combat_config(character)

    cond do
      vitals.qi <= 0 ->
        die(conn, character, attacker)

      Map.get(config, :no_kill, false) and vitals.qi * 3 <= vitals.max_qi ->
        # 点到即止：双方各自脱离战斗（我只通知对方移除我，
        # 对方收到 combat/yield 后也会移除我）
        character =
          put_combat(character, Combat.remove_enemy(character.meta.combat, attacker.id))

        conn = put_character(conn, character)

        yield_to(conn, character, attacker)

      true ->
        conn
    end
  end

  # ---- 死亡与重生 ----

  defp die(conn, character, killer) do
    conn = Broadcast.publish(conn, Messages.death_msg(), n1: character.name)

    # 击杀奖励：经验/潜能之外顺带掉落少量铜钱（A10/N2）与门派贡献（A11/N5）
    # 注意玩家死亡时 meta 为 PlayerMeta（无 loot 字段），需 Map.get 兼容
    reward =
      character.meta.stats
      |> reward_for()
      |> Map.put(:coins, coin_reward())
      |> Map.put(:gongxian, 1)
      |> Map.put(:drops, Map.get(character.meta, :loot) || [])

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

    if npc?(character) do
      # NPC 原地“装死”：dead 标志停掉大脑与心跳，60 秒后原地复活。
      # 不做跨房间瞬移——多次房间频道退订/订阅在特定时序下会以 :error
      # 崩掉 foreman，并在房间存档里堆积重复角色条目。
      character =
        character
        |> Map.put(:status, "#{character.name}的尸体躺在地上。")
        |> put_combat(%Combat{dead: true})

      StatusTracker.mark_dead(character.id)

      conn = put_character(conn, character)
      respawn_ms = respawn_delay(character)
      schedule_self("combat/respawn", %{}, respawn_ms)

      conn
    else
      # 玩家：满血传回出生点
      character =
        character
        |> put_vitals(Vitals.new())
        |> put_combat(Combat.new())

      conn = put_character(conn, character)

      conn
      |> render(CommandView, "revive")
      |> Teleport.teleport(starting_room_id())
    end
  end

  defp npc?(%{meta: %{combat_config: %{spawn_room_id: spawn_room_id}}})
       when is_binary(spawn_room_id),
       do: true

  defp npc?(_), do: false



  def respawn(conn, _event) do
    character = conn.character

    case combat_config(character).spawn_room_id do
      nil ->
        conn

      _room_id ->
        StatusTracker.mark_alive(character.id)

        character =
          character
          |> Map.put(:status, "#{character.name} is here.")
          |> put_vitals(Vitals.new())
          |> put_combat(Combat.new())

        conn
        |> put_character(character)
        |> Broadcast.publish(Messages.revive_msg(), n1: character.name)
    end
  end

  # ---- 敌人变化 ----

  def enemy_died(conn, %{data: %{id: id, exp: exp, potential: potential}} = data) do
    character = conn.character
    combat = Combat.remove_enemy(character.meta.combat, id)

    # 门派贡献：拜师后击杀累积（A11/N5）；玩家才有关注点，NPC meta 防御兼容
    gongxian_gain =
      case Map.get(character.meta, :family) do
        %{name: name} when is_binary(name) and name != "" -> Map.get(data, :gongxian) || 0
        _ -> 0
      end

    stats = %{
      character.meta.stats
      | combat_exp: character.meta.stats.combat_exp + (exp || 0),
        potential: character.meta.stats.potential + (potential || 0),
        gongxian: (character.meta.stats.gongxian || 0) + gongxian_gain
    }

    coins = (Map.get(character.meta, :coins) || 0) + (Map.get(data, :coins) || 0)
    character = Map.put(character, :meta, Map.put(character.meta, :coins, coins))
    character = put_stats(character, stats)

    # 掉落物直接入包（v0 简化：不做尸体拾取）
    drops = Enum.map(Map.get(data, :drops) || [], fn item_id ->
      %Kalevala.World.Item.Instance{
        id: Kalevala.World.Item.Instance.generate_id(),
        item_id: item_id,
        created_at: DateTime.utc_now()
      }
    end)

    character = %{character | inventory: character.inventory ++ drops}

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

  # ---- 目标是尸体：拒绝开战 ----

  def reject_dead(conn, %{data: %{id: id, name: name}}) do
    drop_enemy(conn, id)
    |> render(CommandView, "text", %{text: "#{name}已经倒下了。\n"})
    |> prompt(CommandView, "prompt", %{})
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

    if injured?(vitals) do
      schedule_self("vitals/regen", %{}, @regen_interval)
    end

    character = put_vitals(character, vitals)

    conn
    |> put_character(character)
    |> render(CharacterView, "vitals")
  end

  defp injured?(%Vitals{} = vitals) do
    # 当前值未满 或 上限仍低于基础值（创伤未愈）都算需要回复
    vitals.qi < vitals.max_qi or vitals.jing < vitals.max_jing or
      vitals.neili < vitals.max_neili or
      vitals.max_qi < vitals.base_qi or vitals.max_jing < vitals.base_jing or
      vitals.max_neili < vitals.base_neili
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

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  defp combat_config(%{meta: %{combat_config: %{} = config}}), do: config
  defp combat_config(_), do: %{}

  defp respawn_delay(character) do
    case combat_config(character) do
      %{respawn_delay: ms} when is_integer(ms) and ms > 0 -> ms
      _ -> @default_respawn_delay
    end
  end
  defp starting_room_id() do
    Kantele.World.start_room_id()
  end

  defp reward_for(victim_stats) do
    exp = max(div(victim_stats.combat_exp, 10), 5)
    %{exp: exp, potential: max(div(exp, 2), 2)}
  end

  defp coin_reward(), do: 5 + :rand.uniform(10)

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

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
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Teleport
  alias Kantele.Character.Vitals
  alias Kantele.Character.ConditionEvent
  alias Kantele.Quest

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

  def start(conn, %{data: %{enemy: enemy, initiator_id: initiator_id} = data}) do
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

        # 杀戮意图登记（kill/aggressive）：攻击方记 killer，防守方记 want_kills
        character =
          record_combat_intent(character, enemy, initiator_id, Map.get(data, :type, "fight"))

        conn =
          case initiator_id == character.id do
            true ->
              Broadcast.publish(conn, "$N对著$n一声大喝，蓦地直冲过来！\n",
                n1: character.name,
                n2: enemy.name
              )

            false ->
              # 他人挑衅我：通知我的帮手（coagent）前来助战
              notify_coagents(conn, character, enemy)
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
            # 助战结束且已脱离战斗：清敌并（若在助战）回 startroom
            finish_help(conn, character, combat)

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

    # 被动应战：挨打即入场。对方未走房间 engage（如复活窗口期的残留心跳）
    # 时在此补上敌人并启动心跳，保证战斗闭环与死亡结算都有对象可发。
    {combat, new_fight?} =
      if Combat.enemy?(combat, attacker.id) do
        {combat, false}
      else
        Combat.add_enemy(combat, ref(attacker))
      end

    character = put_combat(character, combat)
    conn = put_character(conn, character)

    if new_fight? do
      schedule_self("combat/tick", %{}, @tick_interval)
    end

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

  # ---- 绝招命中结算（攻击型 perform：攻击方放招，防守方结算）----
  #
  # 与 combat/incoming 同构：攻击方进程只发快照，命中随机（依赖防守方 parry）
  # 与忙乱在防守方进程内进行。当前支持「截手式」（huashan-jian/jie）。
  def perform_incoming(conn, %{data: %{attacker: attacker} = data}) do
    character = conn.character

    cond do
      dead?(character) ->
        conn

      not Process.alive?(attacker.pid) ->
        notify_left(conn, character, attacker)

      Map.get(attacker, :room_id) != character.room_id ->
        notify_left(conn, character, attacker)

      Map.get(data, :perform_id) == "huashan-jian/jie" ->
        resolve_jie(conn, character, attacker, data)

      Map.get(data, :perform_id) == "chousui-zhang/dan" ->
        resolve_dan(conn, character, attacker, data)

      true ->
        conn
    end
  end

  def perform_incoming(conn, _event), do: conn

  defp resolve_jie(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "兵器"]

    if Engine.rand(rng, level) > div(parry, 2) do
      combat = Combat.start_busy(combat, div(level, 22) + 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$p瘁不及防，连连倒退几步，一时间无法回手！\n", bindings)
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "但是$p识破了$N的用意，自顾将手中的#{weapon_name}舞成一团光花，" <>
              "$N一怔之下再也攻不进去。\n",
            bindings
          )
        else
          Messages.interpolate("但是$p双手戳点刺拍，将$N的来招一一架开。\n", bindings)
        end

      Broadcast.publish(conn, text)
    end
  end

  # 「炼心弹」目标侧结算（dan.c 95-134）：内力比对 -> 命中/闪避三分支。
  # 内力消耗与忙乱属攻击方状态，经 combat/perform-feedback 回执补扣。
  defp resolve_dan(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    vitals = character.meta.vitals
    stats = character.meta.stats

    bindings = [n1: attacker.name, n2: character.name]

    an = Map.get(data, :an, 0)
    dn = vitals.max_neili + div(vitals.neili, 4)

    cond do
      Engine.rand(rng, max(an, 1)) + div(an, 2) < div(dn * 2, 3) ->
        # 对方内力过高：震灭，攻击方 -150 内力 / busy 3
        send_feedback(attacker, 150, 3)

        Broadcast.publish(
          conn,
          Messages.interpolate("然而$n全然不放在心上，轻轻一抖，已将$N射来的火焰震灭。\n", bindings)
        )

      true ->
        ap = Map.get(data, :ap, 0)

        dp =
          if Map.get(data, :userp, true) do
            Stats.effective(stats, "dodge") + Stats.effective(stats, "martial-cognize")
          else
            Stats.effective(stats, "dodge") + Stats.effective(stats, "parry")
          end

if Engine.rand(rng, max(ap, 1)) + div(ap, 2) > dp do
           # 命中：jing 直接伤害和创伤，攻击方 -220 内力 / busy 2
           # TODO(migrate): handing 毒药、query_skill_prepared 前置
damage = Map.get(data, :damage, 0)
            jing_damage = div(damage, 2)
            jing_wound = div(damage, 3)
            vitals = Vitals.damage(vitals, :jing, jing_damage)
                     |> Vitals.wound(:jing, jing_wound)
            character = %{character | meta: %{character.meta | vitals: vitals}}

            # 火毒
            lvp = Map.get(data, :poison, 0)
            poison_level = div(lvp, 2) + Engine.rand(rng, div(lvp, 2))
            poison_duration = 3 + Engine.rand(rng, div(lvp, 30))
            poison_params = %{
              "level" => poison_level,
              "duration" => poison_duration,
              "remain" => poison_duration,
              "id" => attacker.id,
              "name" => "火毒"
            }
            conn =
              conn
              |> ConditionEvent.apply_poison(poison_params)

             # 护甲 consisence 损耗
             equipped = character.meta.combat.equipped
             armor_name = nil
             consistence_updated = false
             # 检查衣服
             cloth_slot = :cloth
             cloth_snapshot = Map.get(equipped, cloth_slot)
             if cloth_snapshot && is_map(cloth_snapshot) do
               consistence = Map.get(cloth_snapshot, :consistence) || 100
               new_consistence = max(consistence - :rand.uniform(10), 0)
               if new_consistence != consistence do
                 updated_snapshot = Map.put(cloth_snapshot, :consistence, new_consistence)
                 updated_equipped = Map.put(equipped, cloth_slot, updated_snapshot)
                 updated_combat = %{character.meta.combat | equipped: updated_equipped}
                 character = %{character | meta: %{character.meta | combat: updated_combat}}
                 armor_name = Map.get(cloth_snapshot, :name)
                 consistence_updated = true
               end
             end
             # 如果衣服没损耗或没穿衣，检查盔甲
             if not consistence_updated do
               armor_slot = :armor
               armor_snapshot = Map.get(equipped, armor_slot)
               if armor_snapshot && is_map(armor_snapshot) do
                 consistence = Map.get(armor_snapshot, :consistence) || 100
                 new_consistence = max(consistence - :rand.uniform(10), 0)
                 if new_consistence != consistence do
                   updated_snapshot = Map.put(armor_snapshot, :consistence, new_consistence)
                   updated_equipped = Map.put(equipped, armor_slot, updated_snapshot)
                   updated_combat = %{character.meta.combat | equipped: updated_equipped}
                   character = %{character | meta: %{character.meta | combat: updated_combat}}
                   armor_name = Map.get(armor_snapshot, :name)
                   consistence_updated = true
                 end
               end
             end
             # 消息：如果有 armor_name 则使用它，否则肌肤
             wound_text =
               if armor_name do
                 "$n一个不慎，火星顿时溅到#{armor_name}之上，大势燃烧起来，皮肉烧得嗤嗤作响。\n"
               else
                 "$n一个不慎，火星顿时溅到肌肤之上，大势燃烧起来，皮肉烧得嗤嗤作响。\n"
               end

             send_feedback(attacker, 220, 2)

             conn
               |> Broadcast.publish(
                 Messages.interpolate(wound_text, bindings)
               )
               |> put_character(character)
        else
          # 被闪避：攻击方 -100 内力 / busy 3
          send_feedback(attacker, 100, 3)

          Broadcast.publish(
            conn,
            Messages.interpolate(
              "可是$n见势不妙，急忙腾挪身形，终于避开了$N射来的火焰。\n",
              bindings
            )
          )
        end
    end
  end

  defp send_feedback(attacker, neili_cost, busy) do
    if Process.alive?(attacker.pid) do
      send(attacker.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-feedback",
        data: %{neili_cost: neili_cost, busy: busy}
      })
    end
  end

  # 攻击方回执：按目标结算的分支扣内力并进入忙乱（dan.c 的 me->add/start_busy）
  def perform_feedback(conn, %{data: %{neili_cost: neili_cost, busy: busy}}) do
    character = conn.character

    if dead?(character) do
      conn
    else
      vitals = character.meta.vitals
      vitals = %{vitals | neili: max(vitals.neili - neili_cost, 0)}
      combat = Combat.start_busy(character.meta.combat, busy)

      conn
      |> put_character(%{character | meta: %{character.meta | vitals: vitals, combat: combat}})
    end
  end

  def perform_feedback(conn, _event), do: conn

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

    conn =
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

    # wimpy 自动逃跑：气血低于阈值时触发（仅玩家生效）
    check_wimpy(conn, character, ratio)
  end

  defp check_wimpy(conn, character, ratio) do
    wimpy = Map.get(character.meta, :wimpy, 0)

    cond do
      wimpy <= 0 ->
        conn

      ratio > wimpy ->
        conn

      not Combat.fighting?(character.meta.combat) ->
        conn

      true ->
        Broadcast.publish(conn, "看来该找机会逃跑了……\n", n1: character.name)
        |> event("room/flee")
        |> assign(:prompt, false)
    end
  end

  # 他人挑衅我时，通知我登记在案的帮手（coagent.c）前来助战。
  # 帮手可能在其他房间：通过其唯一角色频道（characters:<id>）定位 pid，
  # 直接投递 coagent/help 事件，由帮手侧自行 start_help 决策（移动/参战）。
  defp notify_coagents(conn, character, enemy) do
    case Map.get(character.meta, :coagents) do
      ids when is_list(ids) and ids != [] ->
        Enum.each(ids, fn coagent_id ->
          case coagent_pid(coagent_id) do
            nil ->
              :ok

            pid ->
              send(pid, %Event{
                from_pid: self(),
                topic: "coagent/help",
                data: %{
                  attacker: ref(enemy),
                  mate_room: character.room_id,
                  mate_id: character.id,
                  mate_name: character.name
                }
              })
          end
        end)

        conn

      _ ->
        conn
    end
  end

  defp coagent_pid(coagent_id) when is_binary(coagent_id) do
    case Kantele.Communication.subscribers("characters:#{coagent_id}") do
      [{_channel, pid, _opts} | _] -> pid
      _ -> nil
    end
  end

  defp coagent_pid(_), do: nil

  # 决斗结算（败者端）：若角色死在 competitor 手下，清掉指向胜者的 competitor，
# 胜负文案由胜者端 announce_duel_victory 广播。
defp announce_duel_result(conn, %{meta: %Kantele.Character.PlayerMeta{} = meta} = character, killer) do
  attack = PlayerMeta.attack_state(meta)
  competitor_id = attack.competitor

  if not is_nil(competitor_id) and not is_nil(killer) and killer.id == competitor_id do
    clean_duel_competitor(conn, character, killer)
  else
    conn
  end
end

defp announce_duel_result(conn, _character, _killer), do: conn

# 决斗结算（胜者端）：被杀的目标曾是我的 competitor，则广播胜负文案
defp announce_duel_victory(conn, %{meta: %Kantele.Character.PlayerMeta{} = meta} = character, enemy_id, enemy_name) do
  attack = PlayerMeta.attack_state(meta)

  if attack.competitor == enemy_id do
    conn
    |> Broadcast.publish("$N武艺更胜一筹，胜了与$n的一番较量。\n",
      n1: character.name,
      n2: enemy_name || "对手"
    )
  else
    conn
  end
end

defp announce_duel_victory(conn, _character, _enemy_id, _enemy_name), do: conn

# 清掉指向某 competitor 的状态（败者端将自己清空）
defp clean_duel_competitor(conn, %{meta: %Kantele.Character.PlayerMeta{} = meta} = character, killer) do
  new_meta =
    PlayerMeta.update_attack(meta, fn attack ->
      if attack.competitor == killer.id, do: %{attack | competitor: nil}, else: attack
    end)

  put_character(conn, %{character | meta: new_meta})
end

defp clean_duel_competitor(conn, _character, _killer), do: conn

  # ---- 死亡与重生 ----

  defp die(conn, character, killer) do
    # 决斗结算：倒在 competitor 手下即败者，清理自身决斗状态（胜负广播在胜者端）
    conn = announce_duel_result(conn, character, killer)
    conn = Broadcast.publish(conn, Messages.death_msg(), n1: character.name)

    # 击杀奖励：经验/潜能之外顺带掉落少量铜钱（A10/N2）与门派贡献（A11/N5）
    # 注意玩家死亡时 meta 为 PlayerMeta（无 loot 字段），需 Map.get 兼容
    reward =
      character.meta.stats
      |> reward_for()
      |> Map.put(:coins, coin_reward())
      |> Map.put(:gongxian, 1)
      |> Map.put(:drops, Map.get(character.meta, :loot) || [])

    # Q3-stretch：神秘挑战者被击杀 → 通知 Story 登记处收摊（其余死亡为 no-op）
    notify_challenger_killed(character, killer)

    # Q4 入侵：外族 NPC 被击杀 → 通知 Invasion 守护进程（记录计数/全歼判定/广播）
    notify_invasion_killed(character, killer)

    enemy_ids = Enum.map(character.meta.combat.enemies, & &1.id)

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

    # 击杀者不在敌人列表（被动挨打致死等单方面战斗）也要拿到结算，
    # 否则奖励凭空消失
    if killer.id not in enemy_ids and Process.alive?(killer.pid) do
      send(killer.pid, %Event{
        from_pid: self(),
        topic: "combat/enemy-died",
        data: Map.merge(%{id: character.id, name: character.name}, reward)
      })
    end

    if npc?(character) do
      # NPC 原地“装死”：dead 标志停掉大脑与心跳，60 秒后原地复活。
      # 不做跨房间瞬移——多次房间频道退订/订阅在特定时序下会以 :error
      # 崩掉 foreman，并在房间存档里堆积重复角色条目。
      character =
        character
        |> Map.put(:status, "#{character.name}的尸体躺在地上。")
        |> Map.put(:meta, Map.put(character.meta, :defeated_by, killer && killer.id))
        |> put_combat(%Combat{dead: true})

      StatusTracker.mark_dead(character.id)

      conn = put_character(conn, character)
      respawn_ms = respawn_delay(character)
      schedule_self("combat/respawn", %{}, respawn_ms)

      conn
    else
      # 玩家：满血传回出生点。死亡即了结：清空对所有人的杀戮意图（killer/want_kills）
      character =
        case character.meta do
          %Kantele.Character.PlayerMeta{} = meta ->
            new_meta =
              PlayerMeta.update_attack(meta, fn attack -> %{attack | killer: [], want_kills: []} end)

            %{character | meta: new_meta}

          _ ->
            character
        end

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

  # Q3-stretch：登记者匹配不上时静默（热路径只做一次 cast，开销可忽略）
  defp notify_challenger_killed(character, killer) do
    Kantele.World.Story.Challenger.on_died(character.id, killer)
  rescue
    _e -> :ok
  catch
    :exit, _reason -> :ok
  end

  def respawn(conn, _event) do
    character = conn.character

    case combat_config(character).spawn_room_id do
      nil ->
        conn

      _room_id ->
        StatusTracker.mark_alive(character.id)

        # NPC 配置的气血上限存在 base_*（创伤只削当前值/max），
        # 从 base 还原；不能用 Vitals.new()（那是玩家默认值）
        v = character.meta.vitals

        vitals = %Vitals{
          v
          | qi: v.base_qi,
            max_qi: v.base_qi,
            jing: v.base_jing,
            max_jing: v.base_jing,
            neili: v.base_neili,
            max_neili: v.base_neili
        }

        meta =
          character.meta
          |> Map.put(:been_cut, nil)
          |> Map.put(:defeated_by, nil)

        character =
          character
          |> Map.put(:status, "#{character.name} is here.")
          |> Map.put(:meta, meta)
          |> put_vitals(vitals)
          |> put_combat(Combat.new())

        conn
        |> put_character(character)
        |> Broadcast.publish(Messages.revive_msg(), n1: character.name)
    end
  end

  # ---- 敌人变化 ----

  def enemy_died(conn, %{data: %{id: id, exp: exp, potential: potential} = reward}) do
    character = conn.character
    combat = Combat.remove_enemy(character.meta.combat, id)

    # 决斗胜负：若倒下的正是我 competitor，则这边是胜者，广播胜负
    conn = announce_duel_victory(conn, character, id, Map.get(reward, :name))

    # 敌人已死：杀戮意图完结，从 killer/want_kills 移除
    character = clear_kill_intent(character, id)

    # 门派贡献：拜师后击杀累积（A11/N5）；玩家才有关注点，NPC meta 防御兼容
    gongxian_gain =
      case Map.get(character.meta, :family) do
        %{name: name} when is_binary(name) and name != "" -> Map.get(reward, :gongxian) || 0
        _ -> 0
      end

    stats = %{
      character.meta.stats
      | combat_exp: character.meta.stats.combat_exp + (exp || 0),
        potential: character.meta.stats.potential + (potential || 0),
        gongxian: (character.meta.stats.gongxian || 0) + gongxian_gain
    }

    coins = (Map.get(character.meta, :coins) || 0) + (Map.get(reward, :coins) || 0)
    character = Map.put(character, :meta, Map.put(character.meta, :coins, coins))
    character = put_stats(character, stats)
    character = apply_quest_kill(character, id)

    # 掉落物直接入包（v0 简化：不做尸体拾取）
    drops =
      Enum.map(Map.get(reward, :drops) || [], fn item_id ->
        %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: item_id,
          created_at: DateTime.utc_now()
        }
      end)

    character = %{character | inventory: character.inventory ++ drops}

    Kantele.Character.Records.save(character)
    share_team_reward(character, exp, potential)

    conn
    |> finish_help(character, combat)
    |> render(CommandView, "kill-reward", %{exp: exp, potential: potential})
    |> prompt(CommandView, "prompt", %{})
  end

  # 队伍击杀分享（Batch 6 team）：击杀者本队其余存活成员各获部分经验/潜能
  defp share_team_reward(character, exp, potential) do
    case Map.get(character.meta, :team) do
      %{members: members} ->
        others =
          Enum.reject(members, fn member ->
            not Process.alive?(member.pid) || member.pid == character.pid
          end)

        share_exp = div(exp || 0, 2)
        share_pot = div(potential || 0, 2)

        if share_exp > 0 or share_pot > 0 do
          Enum.each(others, fn member ->
            send(member.pid, %Kalevala.Event{
              from_pid: self(),
              topic: "team/xp-share",
              data: %{exp: share_exp, potential: share_pot}
            })
          end)
        end

      _ ->
        :ok
    end
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

    # 对手停手/离开/倒下：清理对它的杀戮意图
    character = clear_kill_intent(character, id)

    conn
    |> finish_help(character, combat)
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

  # ---- 战斗意图（F_ATTACK killer/want_kills/competitor，LPC kill_ob/duel）----
  #
  # 仅玩家维护杀戮意图（NPC meta 为 NonPlayerMeta，无 attack 字段，直接忽略）

  # kill/aggressive 开战即互记意图：攻击方把对手加入 killer，防守方把攻击者加入
  # want_kills（宣告"有人想杀我"）。fight/touxi 不记意图（点到为止类）。
  # duel 则双方互为 competitor（F_ATTACK 决斗，LPC duel 命令：败者倒下分出胜负）。
  defp record_combat_intent(%{meta: %Kantele.Character.PlayerMeta{}} = character, enemy, initiator_id, type) do
    character =
      case type do
        t when t in ["kill", "aggressive", "duel"] ->
          if initiator_id == character.id do
            add_attack(character, :killer, enemy.id)
          else
            add_attack(character, :want_kills, enemy.id)
          end

        _ ->
          character
      end

    case type do
      "duel" -> set_competitor(character, enemy.id)
      _ -> character
    end
  end

  defp record_combat_intent(character, _enemy, _initiator_id, _type), do: character

  # 角色害死（enemy-died）时已结算完结，双方意图都在攻击方侧移除对手；
  # 对手死亡/离场/停手则各自从 killer/want_kills 移除对方
  defp clear_kill_intent(%{meta: %Kantele.Character.PlayerMeta{}} = character, id) do
    character
    |> remove_attack(:killer, id)
    |> remove_attack(:want_kills, id)
    |> clear_competitor(id)
  end

  defp clear_kill_intent(character, _id), do: character

  defp add_attack(%{meta: %Kantele.Character.PlayerMeta{} = meta} = character, key, id) do
    new_meta =
      PlayerMeta.update_attack(meta, fn attack ->
        list = attack[key] || []

        if id in list do
          attack
        else
          Map.put(attack, key, [id | list])
        end
      end)

    %{character | meta: new_meta}
  end

  defp add_attack(character, _key, _id), do: character

  defp remove_attack(%{meta: %Kantele.Character.PlayerMeta{} = meta} = character, key, id) do
    new_meta =
      PlayerMeta.update_attack(meta, fn attack ->
        Map.put(attack, key, List.delete(attack[key] || [], id))
      end)

    %{character | meta: new_meta}
  end

  defp remove_attack(character, _key, _id), do: character

  defp set_competitor(%{meta: %Kantele.Character.PlayerMeta{} = meta} = character, id) do
    new_meta = PlayerMeta.update_attack(meta, fn attack -> %{attack | competitor: id} end)
    %{character | meta: new_meta}
  end

  defp set_competitor(character, _id), do: character

  defp clear_competitor(%{meta: %Kantele.Character.PlayerMeta{} = meta} = character, id) do
    new_meta =
      PlayerMeta.update_attack(meta, fn attack ->
        if attack.competitor == id do
          %{attack | competitor: nil}
        else
          attack
        end
      end)

    %{character | meta: new_meta}
  end

  defp clear_competitor(character, _id), do: character

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

  # 落盘清理后的战斗状态；若已在助战且已无敌人，触发 coagent/finish 回 startroom
  defp finish_help(conn, character, combat) do
    conn = conn |> put_character(put_combat(character, combat))

    if Combat.helping?(combat) and Enum.empty?(combat.enemies) do
      # combat/finish 由角色自身控制器处理，经自我定时直投（不走房间路由）
      schedule_self("coagent/finish", %{}, 0)
    end

    conn
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp put_vitals(character, vitals),
    do: %{character | meta: Map.put(character.meta, :vitals, vitals)}

  defp put_stats(character, stats),
    do: %{character | meta: Map.put(character.meta, :stats, stats)}

  # 击杀登记：把被杀敌人的裸 key（"zone:key" -> "key"）记入玩家的任务进度
  defp apply_quest_kill(%{meta: %Kantele.Character.NonPlayerMeta{}} = character, _enemy_id) do
    character
  end

  defp apply_quest_kill(character, enemy_id) do
    case PlayerMeta.quests(character.meta) do
      nil ->
        character

      quests ->
        killed_key = enemy_id |> String.split(":") |> List.last()

        case Quest.register_kill(quests, killed_key) do
          {:ok, new_quests} ->
            %{character | meta: Map.put(character.meta, :quests, new_quests)}

          _ ->
            character
        end
    end
  end

  defp send_event(conn, pid, topic, data) do
    send(pid, %Event{from_pid: self(), topic: topic, data: data})
    conn
  end

  # Q4 入侵：检查死者是否为入侵 NPC（meta.kind == "invader" 且有 invader_number）
  defp notify_invasion_killed(character, killer) do
    kind = Map.get(character.meta, :kind)
    number = Map.get(character.meta, :invader_number)

    if kind == "invader" and is_integer(number) do
      Kantele.World.Invasion.on_died(number, killer)
    end
  rescue
    _e -> :ok
  catch
    :exit, _reason -> :ok
  end
end

defmodule Kantele.Feature.Attack do
  @moduledoc """
  攻击/仇恨/自动战斗系统（对应 LPC feature_attack.c / feature_attack.ex）

  纯函数逻辑已在 `lpc_example/ex/feature_attack/feature_attack.ex` 移植并测试通过；
  本模块负责把纯逻辑接入真实框架：Character/Combat/Room/Skill/Item 循环。
  """

  alias Kantele.Character.{PlayerMeta, Combat, Stats}
  alias Kantele.Combat.{Engine, Fighter}
  alias Kantele.World.Room
  alias Kantele.Scheduler

  @max_opponents 4

  @doc "初始化 attack 状态"
  def init_attack(character) do
    character
    |> PlayerMeta.update_attack(fn attack ->
      Map.put(attack, :killer, attack.killer || [])
      |> Map.put(:want_kills, attack.want_kills || [])
      |> Map.put(:enemy, attack.enemy || [])
    end)
  end

  # ---- Getters ----

  def enemies(character), do: PlayerMeta.attack_state(character).enemy

  def killers(character), do: PlayerMeta.attack_state(character).killer

  def want_kills(character), do: PlayerMeta.attack_state(character).want_kills

  def default_action(character) do
    attack = PlayerMeta.attack_state(character)
    %{attack.default_object => attack.default_function}
  end

  # ---- Fighting State ----

  @doc "是否正在战斗"
  def fighting?(character, ob \\ nil) do
    case ob do
      nil -> length(enemies(character)) > 0
      ob -> ob in enemies(character)
    end
  end

  @doc "是否正在杀戮目标"
  def killing?(character, ob) do
    id = cond do
      is_binary(ob) -> ob
      is_map(ob) -> ob.id
      true -> nil
    end

    if id == nil do
      length(killers(character)) > 0
    else
      id in killers(character)
    end
  end

  @doc "是否想杀目标"
  def want_kill?(character, id) when is_binary(id) do
    id in want_kills(character)
  end

  @doc "清理离线/失效的 killer/want_kills"
  def update_killer(character) do
    character
    |> PlayerMeta.update_attack(fn attack ->
      killer = if is_list(attack.killer), do: attack.killer, else: []
      want = if is_list(attack.want_kills), do: attack.want_kills, else: []

      # 过滤不在线的
      want = Enum.filter(want, fn id -> find_player(id) != nil end)
      killer = Enum.filter(killer, fn id -> id not in want end)

      %{attack | killer: killer, want_kills: want}
    end)
  end

  # ---- Fight/Kill/Want ----

  @doc "开始战斗（互相加入 enemy 列表）"
  def fight_ob(character, opponent) do
    cond do
      opponent == nil or opponent == character ->
        {:ok, character}

      opponent in enemies(character) ->
        {:ok, character}

      true ->
        env = environment(character)
        if environment(opponent) != env or Room.no_fight?(env) do
          {:ok, character}
        else
          if not living?(character) do
            {:ok, character}
          else
            character = set_heart_beat(character, true)
            character = add_enemy(character, opponent)

            # 守卫且正在杀戮该目标 -> 直接击杀
            if guarder?(character) and killing?(character, opponent.id) do
              character = kill_enemy(character, opponent)
            end

            # 互相战斗
            character = fight_ob(opponent, character)

            {:ok, character}
          end
        end
    end
  end

  @doc "开始杀戮（加入 killer，触发守卫联动）"
  def kill_ob(character, opponent) do
    cond do
      not living?(character) or opponent == nil ->
        {:ok, character}

      true ->
        env = environment(character)
        if environment(opponent) != env or Room.no_fight?(env) do
          {:ok, character}
        else
          guarded = PlayerMeta.get_temp(opponent, "guarded") || []
          if character in guarded do
            {:error, "Cannot kill someone you are guarding!"}
          else
            character = ensure_killer_list(character)
            if opponent.id not in killers(character) do
              character = add_killer(character, opponent.id)
              send_message(opponent, "It looks like #{character.name} wants to kill you!")
            end

            # 触发守卫联动
            character = trigger_guarded_allies(character, character, opponent)

            # 开始战斗
            character = fight_ob(character, opponent)

            {:ok, character}
          end
        end
    end
  end

  @doc "想杀某玩家（加入 want_kills）"
  def want_kill(character, opponent) do
    cond do
      not is_player?(opponent) ->
        {:ok, character}

      true ->
        ob_id = opponent.id
        if killing?(character, ob_id) or want_kill?(character, ob_id) do
          {:ok, character}
        else
          if want_kill?(opponent, character.id) do
            {:ok, character}
          else
            character = add_want_kill(character, ob_id)
            {:ok, character}
          end
        end
    end
  end

  # ---- Enemy Management ----

  @doc "清理失效敌人（不同房间/已死/非杀戮目标）"
  def clean_up_enemy(character) do
    enemy = enemies(character)
    if length(enemy) > 0 do
      enemy = Enum.filter(enemy, fn e ->
        is_map(e) and
        environment(e) == environment(character) and
        (living?(e) or killing?(character, e.id))
      end)
      remove_enemies(character, enemy)
    else
      character
    end
  end

  @doc "随机选择一个对手"
  def select_opponent(character) do
    enemy = enemies(character)
    if length(enemy) == 0 do
      nil
    else
      Enum.random(enemy)
    end
  end

  @doc "移除单个敌人"
  def remove_enemy(character, opponent) do
    enemy = List.delete(enemies(character), opponent)
    remove_enemies(character, enemy)
  end

  @doc "移除 killer（含 want_kills）"
  def remove_killer(character, opponent) do
    character =
      if is_player?(opponent) do
        remove_want_kill(character, opponent.id)
      else
        character
      end

    if killing?(character, opponent) do
      character = remove_killer_id(character, opponent.id)
      remove_enemy(character, opponent)
    else
      remove_enemy(character, opponent)
    end
  end

  @doc "清空所有敌人（可选强制）"
  def remove_all_enemy(character, force \\ false) do
    character = PlayerMeta.delete_temp(character, "combat_time")
    enemy = enemies(character)
    if length(enemy) == 0 do
      character
    else
      enemy = Enum.reduce(enemy, [], fn e, acc ->
        if is_map(e) and (force or not killing?(character, e.id)) do
          # 对方也移除我们
          remove_enemy(e, character)
          [e | acc]
        else
          [e | acc]
        end
      end)
      remove_enemies(character, enemy)
    end
  end

  @doc "清空所有想杀列表"
  def remove_all_want(character) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | want_kills: []}
    end)
  end

  @doc "清空所有仇恨/战斗状态"
  def remove_all_killer(character) do
    character
    |> remove_all_want()
    |> remove_all_enemy(true)
    |> PlayerMeta.update_attack(fn attack -> %{attack | killer: []} end)
  end

  # ---- Competitor System ----

  @doc "查询当前竞争对手"
  def competitor(character), do: PlayerMeta.attack_state(character).competitor

  @doc "设置竞争对手"
  def set_competitor(character, opponent) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | competitor: opponent}
    end)
  end

  @doc "开始决斗（双方互设 competitor + fight_ob）"
  def competition_with(character, opponent) do
    character = set_competitor(character, opponent)
    character = fight_ob(character, opponent)
    opponent = set_competitor(opponent, character)
    fight_ob(opponent, character)
    character
  end

  @doc "决斗胜利"
  def win(character) do
    run_override(character, "win")
    PlayerMeta.update_attack(character, fn attack -> %{attack | competitor: nil} end)
  end

  @doc "决斗失败"
  def lost(character) do
    run_override(character, "lost")
    PlayerMeta.update_attack(character, fn attack -> %{attack | competitor: nil} end)
  end

  # ---- Action System ----

  @doc "查询下一步动作"
  def query_action(character, flag) do
    action = PlayerMeta.attack_state(character).next_action
    if flag == true or not is_function(action) do
      action
    else
      action.(character)
    end
  end

  @doc "设置动作"
  def set_action(character, action, fun) do
    cond do
      is_map(action) or is_function(action) ->
        PlayerMeta.update_attack(character, fn attack ->
          %{attack | next_action: action}
        end)
      is_binary(action) or is_map(action) ->
        PlayerMeta.update_attack(character, fn attack ->
          %{attack | next_action: fn _ -> apply(action, fun, [character]) end}
        end)
      true ->
        {:error, "Invalid action"}
    end
  end

  @doc "设置默认动作"
  def set_default_action(character, object, fun) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | default_object: object, default_function: fun}
    end)
  end

  @doc "重置动作（根据武器/准备技能）"
  def reset_action(character) do
    prepare = Stats.get_prepared(character.meta.stats)
    weapon = PlayerMeta.get_temp(character, "weapon")

    type = cond do
      weapon ->
        type = Item.get_skill_type(weapon)
        if type == "pin", do: "sword", else: type
      not prepare or map_size(prepare) == 0 ->
        "unarmed"
      map_size(prepare) == 1 ->
        Map.keys(prepare) |> Enum.at(0)
      map_size(prepare) == 2 ->
        Map.keys(prepare) |> Enum.at(PlayerMeta.get_temp(character, "action_flag") || 0)
    end

    skill = Stats.get_mapped(character.meta.stats, type)
    if skill != nil and Stats.skill(character.meta.stats, skill) > 0 do
      if weapon do
        set_action(character, fn _ -> Skill.query_action(skill, character.meta.stats, weapon) end, 0)
      else
        set_action(character, fn _ -> Skill.query_action(skill, character.meta.stats) end, 0)
      end
    else
      if weapon do
        set_action(character, Item.get_actions(weapon), 0)
      else
        attack = PlayerMeta.attack_state(character)
        set_action(character, attack.default_object, attack.default_function)
      end
    end
  end

  # ---- Heartbeat Attack ----

  @doc "心跳攻击（选对手 -> Combat.fight）"
  def attack(character) do
    character = clean_up_enemy(character)
    opponent = select_opponent(character)

    if opponent do
      character = PlayerMeta.put_temp(character, "last_opponent", opponent)
      character = PlayerMeta.add_temp(character, "combat_time", 1)
      Combat.fight(character, opponent)
      {:ok, character}
    else
      {:ok, character}
    end
  end

  # ---- Init / Auto-fight ----

  @doc "初始化自动战斗（仇恨/血仇/主动攻击）"
  def init(character) do
    # this_player 在命令层上下文中可用
    this_player = this_player()
    me = character

    if not living?(me) or this_player == nil or not living?(this_player) or
       length(enemies(me)) > 0 or (not interactive?(this_player) and not interactive?(me)) do
      {:ok, me}
    else
      # 仇恨自动战斗
      if interactive?(this_player) and killing?(me, this_player.id) do
        if interactive?(me) do
          if not want_kill?(me, this_player.id) do
            me = remove_killer(me, this_player)
            {:ok, me}
          else
            Combat.auto_fight(me, this_player, "hatred")
            {:ok, me}
          end
        else
          Combat.auto_fight(me, this_player, "hatred")
          {:ok, me}
        end
      else
        # 血仇自动战斗
        vendetta_mark = Map.get(entire_dbase(me), "vendetta_mark")
        vend = Map.get(entire_dbase(this_player), "vendetta")
        if vendetta_mark and vend and Map.get(vend, vendetta_mark) do
          Combat.auto_fight(me, this_player, "vendetta")
          {:ok, me}
        else
          # 主动攻击（NPC）
          if not is_player?(this_player) and Map.get(entire_dbase(me), "attitude") == "aggressive" do
            Combat.auto_fight(me, this_player, "aggressive")
            {:ok, me}
          else
            {:ok, me}
          end
        end
      end
    end
  end

  # ---- Helpers ----

  defp ensure_killer_list(character) do
    if not is_list(killers(character)) do
      PlayerMeta.update_attack(character, fn attack -> %{attack | killer: []} end)
    else
      character
    end
  end

  defp trigger_guarded_allies(character, attacker, victim) do
    guarded = PlayerMeta.get_temp(victim, "guarded") || []
    Enum.reduce(guarded, character, &process_guardian(&1, &2, attacker, victim))
  end

  defp process_guardian(guardian, acc, attacker, victim) do
    if guardian == nil or guardian == attacker or environment(guardian) != environment(acc) do
      acc
    else
      if not living?(guardian) or killing?(guardian, attacker.id) do
        acc
      else
        acc =
          acc
          |> send_message("#{victim.name} is under attack, you step forward to join the battle!")

        message = case :rand.uniform(8) do
          1 -> template_attack(1, attacker, victim)
          2 -> template_attack(2, attacker, victim)
          3 -> template_attack(3, attacker, victim)
          4 -> template_attack(4, attacker, victim)
          5 -> template_attack(5, attacker, victim)
          6 -> template_attack(6, attacker, victim)
          7 -> template_attack(7, attacker, victim)
          _ -> template_attack(8, attacker, victim)
        end
        message = replace_vars(message, attacker, victim)
        broadcast_message(message, guardian, attacker)

        if want_kill?(guardian, attacker.id) do
          acc = want_kill(acc, attacker)
        end

        kill_ob(acc, attacker)
      end
    end
  end

  defp template_attack(num, attacker, victim) do
    n = attacker.name
    v = victim.name
    case num do
      1 -> "#{n} silently attacks #{v}!"
      2 -> "#{n} roars and charges at #{v}!"
      3 -> "#{n} coldly says: \"Take this!\" and attacks #{v}!"
      4 -> "#{n} steps forward to block #{v}!"
      5 -> "#{n} vibrates arms, attacking #{v} relentlessly!"
      6 -> "#{n} breathes deep, striking at #{v}'s vital point!"
      7 -> "#{n} presses the attack on #{v}!"
      _ -> "#{n} flies at #{v}!"
    end
  end

  defp replace_vars(template, attacker, victim) do
    template
    |> String.replace("$N", attacker.name)
    |> String.replace("$n", victim.name)
  end

  # ---- 内部辅助 ----

  defp add_enemy(character, opponent) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | enemy: [opponent | attack.enemy]}
    end)
  end

  defp remove_enemies(character, enemy_list) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | enemy: enemy_list}
    end)
  end

  defp add_killer(character, id) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | killer: [id | attack.killer]}
    end)
  end

  defp remove_killer_id(character, id) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | killer: List.delete(attack.killer, id)}
    end)
  end

  defp add_want_kill(character, id) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | want_kills: [id | attack.want_kills]}
    end)
  end

  defp remove_want_kill(character, id) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | want_kills: List.delete(attack.want_kills, id)}
    end)
  end

  defp kill_enemy(character, opponent) do
    character = remove_killer_id(character, opponent.id)
    remove_enemy(character, opponent)
  end

  # ---- 存根函数（后续接入真实实现） ----

  defp this_player(), do: nil

  defp entire_dbase(character), do: Map.merge(character.meta.stats.__struct__(), character.meta.temp)

  defp find_player(_id), do: nil

  defp living?(%{meta: %{vitals: vitals}}), do: vitals.qi > 0 || vitals.jing > 0

  defp interactive?(_character), do: true

  defp environment(character), do: character.meta.zone_id

  defp guarder?(_character), do: false

  defp is_player?(%{id: id}), do: is_binary(id) && String.starts_with?(id, "player:")

  defp no_fight?(_env), do: false

  defp set_heart_beat(_character, _enabled), do: :ok

  defp send_message(_character, _msg), do: :ok

  defp broadcast_message(_msg, _a, _b), do: :ok

  defp run_override(_character, _name), do: :ok

  defp combat_fight(_character, _opponent), do: :ok
  defp combat_auto_fight(_me, _ob, _type), do: :ok

  defp skill_get_prepared(_stats), do: %{}
  defp skill_get_mapped(_stats, _type), do: nil
  defp skill_get_level(_character, _skill), do: 0
  defp skill_query_action(_skill, _stats, _weapon \\ nil), do: nil

  defp item_get_skill_type(_weapon), do: "sword"
  defp item_get_actions(_weapon), do: []
end
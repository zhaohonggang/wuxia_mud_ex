defmodule Kantele.Feature.Attack do
  @moduledoc """
  攻击/仇恨/决斗系统 —— 真实引擎的薄查询层

  所有状态存储在 `PlayerMeta` 的 attack_* 字段中；
  真实战斗流程由 `CombatEvent` + `Kantele.Character.Combat` 管理。
  本模块仅提供读取/写入接口，不再包含并行战斗逻辑。
  """

  alias Kantele.Character.{PlayerMeta, Combat}
  alias Kantele.World.Room

  @doc "初始化 attack 状态（确保字段存在）"
  def init_attack(character) do
    PlayerMeta.update_attack(character, fn attack ->
      Map.put_new(attack, :killer, attack.killer || [])
      |> Map.put_new(:want_kills, attack.want_kills || [])
      |> Map.put_new(:enemy, attack.enemy || [])
    end)
  end

  # ---- Getters ----

  def enemies(character), do: PlayerMeta.attack_state(character).enemy

  def killers(character), do: PlayerMeta.attack_state(character).killer

  def want_kills(character), do: PlayerMeta.attack_state(character).want_kills

  def competitor(character), do: PlayerMeta.attack_state(character).competitor

  def default_action(character) do
    attack = PlayerMeta.attack_state(character)
    %{attack.default_object => attack.default_function}
  end

  # ---- Fighting State ----

  @doc "是否正在战斗（读取真实 Combat.enemies）"
  def fighting?(character, ob \\ nil) do
    case ob do
      nil -> Combat.fighting?(character.meta.combat)
      ob -> Combat.enemy?(character.meta.combat, ob.id)
    end
  end

  @doc "是否标记为要杀目标（killer 列表）"
  def killing?(character, ob) do
    id = if is_binary(ob), do: ob, else: Map.get(ob, :id)
    if id == nil do
      length(killers(character)) > 0
    else
      id in killers(character)
    end
  end

  @doc "是否在想杀列表"
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

  @doc "开始战斗：在真实引擎中已由 fight/kill 命令通过 combat/start 处理；
   这里仅记录 killer 意图（若尚未记录）"
  def fight_ob(character, opponent) do
    if opponent == nil or opponent == character do
      {:ok, character}
    else
      character = add_killer(character, opponent.id)
      {:ok, character}
    end
  end

  @doc "声明杀戮意图：加入 killer 列表（对应 LPC kill_ob）"
  def kill_ob(character, opponent) do
    cond do
      not living?(character) or opponent == nil ->
        {:ok, character}

      true ->
        character = ensure_killer_list(character)

        if opponent.id not in killers(character) do
          character = add_killer(character, opponent.id)
        end

        {:ok, character}
    end
  end

  @doc "想杀某玩家（加入 want_kills，不立即开战）"
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

  # ---- Enemy Management (委托给真实 Combat) ----

  def clean_up_enemy(character) do
    # 真实引擎在 CombatEvent.tick 中清理
    PlayerMeta.update_attack(character, fn attack -> %{attack | enemy: []} end)
  end

  def select_opponent(character) do
    # 真实引擎在 CombatEvent.tick 中随机选择
    case character.meta.combat.enemies do
      [] -> nil
      enemies -> Enum.random(enemies)
    end
  end

  def remove_enemy(character, opponent) do
    enemy = List.delete(enemies(character), opponent)
    PlayerMeta.update_attack(character, fn attack -> %{attack | enemy: enemy} end)
  end

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

  def remove_all_enemy(character, force \\ false) do
    character = PlayerMeta.delete_temp(character, "combat_time")
    enemy = enemies(character)

    if length(enemy) == 0 do
      character
    else
      enemy =
        Enum.reduce(enemy, [], fn e, acc ->
          if is_map(e) and (force or not killing?(character, e.id)) do
            [e | acc]
          else
            [e | acc]
          end
        end)

      PlayerMeta.update_attack(character, fn attack -> %{attack | enemy: enemy} end)
    end
  end

  def remove_all_want(character) do
    PlayerMeta.update_attack(character, fn attack -> %{attack | want_kills: []} end)
  end

  def remove_all_killer(character) do
    character
    |> remove_all_want()
    |> remove_all_enemy(true)
    |> PlayerMeta.update_attack(fn attack -> %{attack | killer: []} end)
  end

  # ---- Competitor / Duel ----

  def set_competitor(character, opponent) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | competitor: opponent}
    end)
  end

  def competition_with(character, opponent) do
    character = set_competitor(character, opponent)
    opponent = set_competitor(opponent, character)
    character
  end

  def win(character) do
    PlayerMeta.update_attack(character, fn attack -> %{attack | competitor: nil} end)
  end

  def lost(character) do
    PlayerMeta.update_attack(character, fn attack -> %{attack | competitor: nil} end)
  end

  # ---- Action System ----

  def query_action(character, flag) do
    action = PlayerMeta.attack_state(character).next_action

    if flag == true or not is_function(action) do
      action
    else
      action.(character)
    end
  end

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

  def set_default_action(character, object, fun) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | default_object: object, default_function: fun}
    end)
  end

  def reset_action(character) do
    weapon = PlayerMeta.get_temp(character, "weapon")
    prepare = Kantele.Character.Stats.mapped(character.meta.stats)

    type =
      cond do
        weapon ->
          type = Kantele.Item.get_skill_type(weapon)
          if type == "pin", do: "sword", else: type

        not prepare or map_size(prepare) == 0 ->
          "unarmed"

        map_size(prepare) == 1 ->
          Map.keys(prepare) |> Enum.at(0)

        map_size(prepare) == 2 ->
          Map.keys(prepare) |> Enum.at(PlayerMeta.get_temp(character, "action_flag") || 0)
      end

    skill = Kantele.Character.Stats.mapped(character.meta.stats, type)

    if skill != nil and Kantele.Character.Stats.skill(character.meta.stats, skill) > 0 do
      if weapon do
        set_action(
          character,
          fn _ -> Kantele.Combat.Skills.query_action(skill, 1, &:rand.uniform/1) end,
          0
        )
      else
        set_action(character, fn _ -> Kantele.Combat.Skills.query_action(skill, 1, &:rand.uniform/1) end, 0)
      end
    else
      if weapon do
        set_action(character, Kantele.Item.get_actions(weapon), 0)
      else
        attack = PlayerMeta.attack_state(character)
        set_action(character, attack.default_object, attack.default_function)
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

  defp add_enemy(character, opponent) do
    PlayerMeta.update_attack(character, fn attack ->
      %{attack | enemy: [opponent | attack.enemy]}
    end)
  end

  defp remove_enemies(character, enemy_list) do
    PlayerMeta.update_attack(character, fn attack -> %{attack | enemy: enemy_list} end)
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

  # ---- Stubs (与真实引擎对接) ----

  defp find_player(_id), do: nil

  defp living?(%{meta: %{vitals: vitals}}), do: vitals.qi > 0 || vitals.jing > 0

  defp is_player?(%{id: id}), do: is_binary(id) && String.starts_with?(id, "player:")

  defp environment(character), do: character.meta.zone_id
end
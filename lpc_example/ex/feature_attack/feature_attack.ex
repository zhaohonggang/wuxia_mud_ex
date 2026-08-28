defmodule ExKantele.World.Feature.Attack do
  @moduledoc """
  Attack System (F_ATTACK)
  Source: lpc_example/feature/feature_attack.c (537 lines)

  Full migration: enemy/killer/want_kills management, fight/kill/want_kill,
  enemy cleanup, competitor system, action system, attack/heart_beat, init auto-fight.
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Combat, Skill, Room}

  @max_opponents 4

  def init_feature(state) do
    Map.put(state, :attack, %{
      killer: [],
      want_kills: [],
      enemy: [],
      next_action: nil,
      default_object: nil,
      default_function: nil,
      competitor: nil
    })
  end

  def init(state, player) do
    me = player
    ob = Player.this_player()

    if not Player.living?(me) or ob == nil or not Player.living?(ob) or
       length(state.attack.enemy) > 0 or (not Player.interactive?(ob) and not Player.interactive?(me)) do
      {:ok, state}
    else
      my = Player.entire_dbase(player)
      its = Player.entire_dbase(ob)

      # Auto-fight: hatred
      if Player.interactive?(ob) and is_killing(state, its["id"]) do
        if Player.interactive?(me) do
          if not is_want_kill(state, its["id"]) do
            state = remove_killer(state, ob)
            {:ok, state}
          else
            Combat.auto_fight(state, me, ob, "hatred")
            {:ok, state}
          end
        else
          Combat.auto_fight(state, me, ob, "hatred")
          {:ok, state}
        end
      # Auto-fight: vendetta
      elsif vendetta_mark = my["vendetta_mark"] and its["vendetta"][vendetta_mark] do
        Combat.auto_fight(state, me, ob, "vendetta")
        {:ok, state}
      # Auto-fight: aggressive
      elsif not Player.is_player?(ob) and my["attitude"] == "aggressive" do
        Combat.auto_fight(state, me, ob, "aggressive")
        {:ok, state}
      else
        {:ok, state}
      end
    end
  end

  # --- Getters ---

  def get_enemies(state), do: state.attack.enemy
  def get_killers(state), do: state.attack.killer
  def get_want_kills(state), do: state.attack.want_kills
  def get_default_action(state), do: %{state.attack.default_object => state.attack.default_function}

  # --- Fighting State ---

  def is_fighting(state, ob \\ nil) do
    if ob == nil do
      length(state.attack.enemy) > 0
    else
      ob in state.attack.enemy
    end
  end

  def is_killing(state, ob) do
    id = cond do
      is_binary(ob) -> ob
      is_map(ob) -> Player.id(ob)
      true -> nil
    end

    if id == nil do
      length(state.attack.killer) > 0
    else
      id in state.attack.killer
    end
  end

  def is_want_kill(state, id) when is_binary(id) do
    id in state.attack.want_kills
  end

  def update_killer(state) do
    new_killer = if is_list(state.attack.killer), do: state.attack.killer, else: []
    new_want = if is_list(state.attack.want_kills), do: state.attack.want_kills, else: []

    new_want = Enum.filter(new_want, fn id -> Player.find_player(id) != nil end)
    new_killer = Enum.filter(new_killer, fn id -> id not in new_want end)

    put_in(state, [:attack, :killer], new_killer)
    |> put_in([:attack, :want_kills], new_want)
  end

  # --- Fight/Kill/Want ---

  def fight_ob(state, player, ob) do
    cond do
      ob == nil or ob == player -> {:ok, state}
      ob in state.attack.enemy -> {:ok, state}

      true ->
        env = Player.environment(player)
        if Player.environment(ob) != env or Room.no_fight?(env) do
          {:ok, state}
        else
          if not Player.living?(player) do
            {:ok, state}
          else
            state = Player.set_heart_beat(player, true)
            state = put_in(state, [:attack, :enemy], [ob | state.attack.enemy])

            if Player.is_guarder?(player) and is_killing(state, ob) do
              state = kill_enemy(state, player, ob)
            end

            # Reciprocal fight
            state = fight_ob(state, ob, player)
          end
        end
    end
  end

  def kill_ob(state, player, ob) do
    cond do
      not Player.living?(player) or ob == nil -> {:ok, state}
      true ->
        env = Player.environment(player)
        if Player.environment(ob) != env or Room.no_fight?(env) do
          {:ok, state}
        else
          guarded = Player.get_temp(ob, "guarded") || []
          if player in guarded do
            {:error, "Cannot kill someone you are guarding!"}
          else
            state = ensure_killer_list(state)
            if Player.id(ob) not in state.attack.killer do
              state = put_in(state, [:attack, :killer], [Player.id(ob) | state.attack.killer])
              send_message(ob, "It looks like #{Player.name(player)} wants to kill you!")
            end

            # Trigger guarded allies
            state = trigger_guarded_allies(state, player, ob)

            state = fight_ob(state, player, ob)
          end
    end
  end

  def want_kill(state, player, ob) do
    cond do
      not Player.is_player?(ob) -> {:ok, state}
      true ->
        ob_id = Player.id(ob)
        if is_killing(state, ob_id) or is_want_kill(state, ob_id) do
          {:ok, state}
        else
          if is_want_kill(Player.get_state(ob), Player.id(player)) do
            {:ok, state}
          else
            put_in(state, [:attack, :want_kills], [ob_id | state.attack.want_kills])
          end
        end
    end
  end

  # --- Enemy Management ---

  def clean_up_enemy(state, player) do
    enemy = state.attack.enemy
    if length(enemy) > 0 do
      enemy = Enum.filter(enemy, fn e ->
        is_map(e) and
        Player.environment(e) == Player.environment(state.player) and
        (Player.living?(e) or is_killing(state, Player.id(e)))
      end)
      put_in(state, [:attack, :enemy], enemy)
    else
      state
    end
  end

  def select_opponent(state, player) do
    enemy = state.attack.enemy
    if length(enemy) == 0 do
      nil
    else
      Enum.random(enemy)
    end
  end

  def remove_enemy(state, player, ob) do
    enemy = List.delete(state.attack.enemy, ob)
    state = put_in(state, [:attack, :enemy], enemy)
    if length(enemy) == 0 do
      Player.delete_temp(player, "combat_time")
    end
    state
  end

  def remove_killer(state, player, ob) do
    if Player.is_player?(ob) do
      state = put_in(state, [:attack, :want_kills], List.delete(state.attack.want_kills, Player.id(ob)))
    end

    if is_killing(state, ob) do
      state = put_in(state, [:attack, :killer], List.delete(state.attack.killer, Player.id(ob)))
      remove_enemy(state, ob)
    else
      remove_enemy(state, ob)
    end
  end

  def remove_all_enemy(state, player, force \\ false) do
    state = Player.delete_temp(player, "combat_time")
    enemy = state.attack.enemy
    if length(enemy) == 0 do
      state
    else
      enemy = Enum.reduce(enemy, [], fn e, acc ->
        if is_map(e) and (force or not is_killing(state, Player.id(e))) do
          remove_enemy(Player.get_state(e), state.player)
          [e | acc]
        else
          [e | acc]
        end
      end)
      put_in(state, [:attack, :enemy], enemy)
    end
  end

  def remove_all_want(state) do
    put_in(state, [:attack, :want_kills], [])
  end

  def remove_all_killer(state) do
    state = put_in(state, [:attack, :enemy], Enum.filter(state.attack.enemy, &(&1 != nil)))
    state = remove_all_want(state)
    Enum.each(state.attack.enemy, fn e ->
      remove_killer(Player.get_state(e), state.player)
    end)
    put_in(state, [:attack, :killer], [])
    |> put_in([:attack, :enemy], Enum.filter(state.attack.enemy, &(&1 != nil)))
  end

  # --- Competitor System ---

  def query_competitor(state), do: state.attack.competitor
  def set_competitor(state, ob), do: put_in(state, [:attack, :competitor], ob)

  def competition_with(state, player, ob) do
    state = set_competitor(state, ob)
    state = fight_ob(state, player, ob)
    state = set_competitor(Player.get_state(ob), player)
    state = fight_ob(Player.get_state(ob), ob, player)
    state
  end

  def win(state) do
    run_override(state, "win")
    put_in(state, [:attack, :competitor], nil)
  end

  def lost(state) do
    run_override(state, "lost")
    put_in(state, [:attack, :competitor], nil)
  end

  # --- Action System ---

  def query_action(state, flag) do
    if flag or not is_function(state.attack.next_action) do
      state.attack.next_action
    else
      state.attack.next_action.(state)
    end
  end

  def set_action(state, action, fun) do
    cond do
      is_map(action) or is_function(action) ->
        put_in(state, [:attack, :next_action], action)
      is_binary(action) or is_map(action) ->
        put_in(state, [:attack, :next_action], fn _ -> apply(action, fun, [state]) end)
      true ->
        {:error, "Invalid action"}
    end
  end

  def set_default_action(state, ob, fun) do
    put_in(state, [:attack, :default_object], ob)
    |> put_in([:attack, :default_function], fun)
  end

  def reset_action(state, player) do
    me = player
    prepare = Skill.get_prepared(me)
    ob = Player.get_temp(player, "weapon")

    type = cond do
      ob ->
        type = Item.get_skill_type(ob)
        if type == "pin", do: "sword", else: type
      not prepare or map_size(prepare) == 0 ->
        "unarmed"
      map_size(prepare) == 1 ->
        Map.keys(prepare) |> Enum.at(0)
      map_size(prepare) == 2 ->
        Map.keys(prepare) |> Enum.at(Player.get_temp(player, "action_flag") || 0)
    end

    if skill = Skill.get_mapped(me, type) and Skill.get_level(me, skill) > 0 do
      if ob do
        set_action(state, fn _ -> Skill.query_action(skill, me, ob) end, 0)
      else
        set_action(state, fn _ -> Skill.query_action(skill) end, 0)
      end
    else
      if ob do
        set_action(state, Item.get_actions(ob), 0)
      else
        set_action(state, state.attack.default_object, state.attack.default_function)
      end
    end
  end

  # --- Heartbeat Attack ---

  def attack(state, player) do
    state = clean_up_enemy(state, player)
    opponent = select_opponent(state, player)

    if opponent do
      state = Player.put_temp(player, "last_opponent", opponent)
      state = Player.add_temp(player, "combat_time", 1)
      Combat.fight(player, opponent)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  # --- Init / Auto-fight ---

  # --- Helpers ---

  defp ensure_killer_list(state) do
    if not is_list(state.attack.killer) do
      put_in(state, [:attack, :killer], [])
    else
      state
    end
  end

  defp trigger_guarded_allies(state, me, ob) do
    guarded = Player.get_temp(ob, "guarded") || []
    Enum.reduce(guarded, state, &process_guardian(&1, &2, me, ob))
  end

  defp process_guardian(gob, acc, me, ob) do
    if gob == nil or gob == me or Player.environment(gob) != Player.environment(acc.player) do
      acc
    else
      if not Player.living?(gob) or Player.is_killing?(gob, Player.id(me)) do
        acc
      else
        acc = send_message(gob, "#{Player.name(ob, 1)} is under attack, you step forward to join the battle!")
        message = case :rand.uniform(8) do
          1 -> template_attack(1, me, you)
          2 -> template_attack(2, me, you)
          3 -> template_attack(3, me, you)
          4 -> template_attack(4, me, you)
          5 -> template_attack(5, me, you)
          6 -> template_attack(6, me, you)
          7 -> template_attack(7, me, you)
          _ -> template_attack(8, me, you)
        end
        message = replace_vars(message, gob, me)
        broadcast_message(message, gob, me)

        if Player.is_want_kill?(gob, Player.id(me)) do
          want_kill(acc, gob, me)
        end

        kill_ob(acc, gob, me)
      end
    end
  end

  defp template_attack(num, me, you) do
    n = Player.name(me)
    y = Player.name(you)
    case num do
      1 -> "#{n} silently attacks #{y}!"
      2 -> "#{n} roars and charges at #{y}!"
      3 -> "#{n} coldly says: \"Take this!\" and attacks #{y}!"
      4 -> "#{n} steps forward to block #{y}!"
      5 -> "#{n} vibrates arms, attacking #{y} relentlessly!"
      6 -> "#{n} breathes deep, striking at #{y}'s vital point!"
      7 -> "#{n} presses the attack on #{y}!"
      _ -> "#{n} flies at #{y}!"
    end
  end

  defp replace_vars(template, me, you) do
    template
    |> String.replace("$N", Player.name(me))
    |> String.replace("$n", Player.name(you))
  end
end
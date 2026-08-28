defmodule ExKantele.World.Feature.Damage do
  @moduledoc """
  Damage System (F_DAMAGE)
  Source: lpc_example/feature/feature_damage.c (637 lines)

  Full migration: receive_damage/wound/heal/curing, unconcious/revive/die,
  ghost state, DPS tracking, heal_up (food/water/jing/qi/jingli/neili),
  max_food/water_capacity.
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Combat, Skill}

  def init_feature(state) do
    Map.put(state, :damage, %{
      last_damage_from: nil,
      last_damage_name: nil,
      defeated_by: nil,
      defeated_by_who: nil,
      ghost: false,
      defeat_player: []
    })
  end

  # --- Getters ---

  def last_damage_from(state), do: state.damage.last_damage_from
  def last_damage_name(state), do: state.damage.last_damage_name
  def defeated_by(state), do: state.damage.defeated_by
  def defeated_by_who(state), do: state.damage.defeated_by_who
  def is_ghost(state), do: state.damage.ghost

  # --- Damage/Healing ---

  defp update_last_damage(state, who) do
    if who and who != state.damage.last_damage_from do
      put_in(state, [:damage, :last_damage_from], who)
      |> put_in([:damage, :last_damage_name], Player.name(who))
    else
      state
    end
  end

  def receive_damage(state, player, type, damage, who \\ nil) do
    cond do
      damage < 0 -> {:error, "Damage cannot be negative"}
      type not in ["jing", "qi"] -> {:error, "Damage type must be 'jing' or 'qi'"}
      true ->
        state = update_last_damage(state, who)
        if who and damage > 150, do: Player.improve_craze(player, div(damage, 5))

        current = Map.get(player, type, 0)
        new_val = max(0, current - damage)
        {:ok, Player.put(player, type, new_val) |> Player.set_heart_beat(true)}
    end
  end

  def receive_wound(state, player, type, damage, who \\ nil) do
    cond do
      damage < 0 -> {:error, "Damage cannot be negative"}
      type not in ["jing", "qi"] -> {:error, "Damage type must be 'jing' or 'qi'"}
      true ->
        state = update_last_damage(state, who)
        if who and damage > 150, do: Player.improve_craze(player, div(damage, 3))

        eff_val = Map.get(player, "eff_#{type}", 0)
        new_eff = max(0, eff_val - damage)
        state = Player.put(player, "eff_#{type}", new_eff)

        current = Map.get(player, type, 0)
        if current > new_eff, do: Player.put(player, type, new_eff)

        Player.set_heart_beat(player, true)
        {:ok, state}
    end
  end

  def receive_heal(state, player, type, heal) do
    cond do
      heal < 0 -> {:error, "Heal cannot be negative"}
      type not in ["jing", "qi"] -> {:error, "Heal type must be 'jing' or 'qi'"}
      true ->
        current = Map.get(player, type, 0)
        eff_val = Map.get(player, "eff_#{type}", 0)
        new_val = min(eff_val, current + heal)
        {:ok, Player.put(player, type, new_val)}
    end
  end

  def receive_curing(state, player, type, heal) do
    cond do
      heal < 0 -> {:error, "Cure cannot be negative"}
      type not in ["jing", "qi"] -> {:error, "Cure type must be 'jing' or 'qi'"}
      true ->
        eff_val = Map.get(player, "eff_#{type}", 0)
        max_val = Map.get(player, "max_#{type}", 0)
        new_eff = min(max_val, eff_val + heal)
        {:ok, Player.put(player, "eff_#{type}", new_eff)}
    end
  end

  # --- DPS Tracking ---

  def dps_count(state) do
    dp = state.damage.defeat_player
    if dp == nil, do: 0, else: length(Enum.filter(dp, &Player.living?/1))
  end

  def record_dp(state, player, ob) do
    if Player.is_want_kill(player, Player.id(ob)) do
      dp = state.damage.defeat_player || []
      if ob in dp, do: state, else: put_in(state, [:damage, :defeat_player], [ob | dp])
    else
      state
    end
  end

  def remove_dp(state, _player, ob) do
    if ob == nil, do: put_in(state, [:damage, :defeat_player], []), else: put_in(state, [:damage, :defeat_player], List.delete(state.damage.defeat_player || [], ob))
  end

  # --- Unconcious/Revive/Die ---

  def unconcious(state, player) do
    cond do
      not Player.living?(player) -> {:ok, state}
      Player.is_wizard?(player) and Player.get_env(player, "immortal") -> {:ok, state}
      true ->
        ob = Player.query_competitor(player)
        if ob and not Player.is_killing(ob, Player.id(player)) do
          Player.win(ob)
          Player.lost(player)
        end

        if Player.busy?(player), do: Player.interrupt_me(player)

        if run_override(player, "unconcious"), do: {:ok, state}, else: handle_unconcious(state, player)
    end
  end

  defp handle_unconcious(state, player) do
    ob = Player.query_competitor(player)
    state = if ob, do: put_in(state, [:damage, :defeated_by], ob), else: state
    state = if ob, do: put_in(state, [:damage, :defeated_by_who], Player.name(ob)), else: state

    if Player.is_player?(player) and ob and Player.is_want_kill(player, Player.id(ob)) do
      state = record_dp(state, player, ob)
    end

    state = clear_enemies(state, player)
    state = put_in(state, [:damage, :block_msg_all], 1)
    state = Player.disable_player(player)
    state = Player.put(player, "jing", 0)
    state = Player.put(player, "qi", 0)
    state = Player.put_temp(player, "block_msg/all", 1)

    delay = 30 + :rand.uniform(100 - Player.con(player))
    schedule_revive(player, delay)

    Combat.announce(player, "unconcious")
    check_player_escape(state, player)

    {:ok, state}
  end

  def revive(state, player, quiet \\ false) do
    Player.remove_call_out(player, "revive")
    env = Player.environment(player)

    if env do
      env = find_valid_room(env)
      if env != Player.environment(player), do: Player.move(player, env)
    end

    Player.delete(player, "disable_type")
    state = Player.put_temp(player, "block_msg/all", 0)
    state = Player.enable_player(player)
    state = Player.write_prompt(player)

    if state.damage.defeated_by do
      Player.remove_dp(state.damage.defeated_by, player)
    end

    if not quiet do
      state = put_in(state, [:damage, :defeated_by], nil)
      state = put_in(state, [:damage, :defeated_by_who], nil)
      Combat.announce(player, "revive")
      send_message(player, "Slowly you regain consciousness...")
    end

    state = put_in(state, [:damage, :last_damage_from], nil)
    state = put_in(state, [:damage, :last_damage_name], nil)
    {:ok, state}
  end

  def die(state, player, killer \\ nil) do
    Player.delete_temp(player, "sleeped")
    Player.delete(player, "last_sleep")

    # Competition
    ob = Player.query_competitor(player)
    if ob, do: (Player.win(ob); Player.lost(player))

    if Player.busy?(player), do: Player.interrupt_me(player)

    if run_override(player, "die"), do: {:ok, state}, else: handle_die(state, player, killer)
  end

  def handle_die(state, player, killer) do
    state = delete_sleep_flags(state, player)

    ob = Player.query_competitor(player)
    if ob, do: (Player.win(ob); Player.lost(player))

    if Player.busy?(player), do: Player.interrupt_me(player)

    if run_override(player, "die") do
      {:ok, state}
    else
      process_death(state, player, killer)
    end
  end

  defp process_death(state, player, killer) do
    state = delete_sleep_flags(state, player)

    ob = Player.query_competitor(player)
    if ob, do: (Player.win(ob); Player.lost(player))

    if Player.busy?(player), do: Player.interrupt_me(player)

    if run_override(player, "die") do
      {:ok, state}
    else
      state = process_death(state, player, killer)
    end
  end

  def reincarnate(state, player) do
    state = put_in(state, [:damage, :ghost], false)
    state = Player.put(player, "eff_jing", Player.max_jing(player))
    state = Player.put(player, "eff_qi", Player.max_qi(player))
    {:ok, state}
  end

  # --- Capacity ---

  def max_food_capacity(state, player) do
    f = Player.str(player) * 10 + 100
    f = if Player.has?(player, "skybook/item/tianshu2"), do: f + 300, else: f
    f = if Player.has?(player, "special_skill/greedy"), do: f + 500, else: f
    f
  end

  def max_water_capacity(state, player) do
    w = Player.str(player) * 10 + 100
    w = if Player.has?(player, "skybook/item/tianshu2"), do: w + 300, else: w
    w = if Player.has?(player, "special_skill/greedy"), do: w + 500, else: w
    w
  end

  # --- Heal Up (Heartbeat) ---

  def heal_up(state, player) do
    state = if Player.get_temp(player, "nopoison"), do: Player.delete_temp(player, "nopoison"), else: state

    if Player.is_in_prison(player) do
      Player.update_in_prison(player)
      return {:ok, state}
    end

    me = player
    is_user = Player.is_player(me)
    scale = if Player.living?(me), do: 1, else: (if is_user, do: 4, else: 8)
    my = Player.entire_dbase(me)

    if not is_user or (Player.environment(me) and not Room.is_chat_room(Player.environment(me)) and
       (not is_binary(my["doing"]) and Player.interactive?(me) or my["doing"] == "scheme")) do

      # Food/Water consumption
      if my["water"] > 0, do: my = Map.put(my, "water", my["water"] - 1)
      if my["food"] > 0, do: my = Map.put(my, "food", my["food"] - 1)

      if my["water"] < 1 and is_user, do: return {:ok, 0}

      # Guard duty
      guard = Player.get_temp(me, "guardfor")
      if guard and (not is_map(guard) or not Player.is_character(guard)) do
        if div(my["jing"] * 100, my["max_jing"]) < 50 do
          send_message(me, "You feel too tired, need to relax.")
          return {:ok, 0}
        end

        my = Map.put(my, "jing", my["jing"] - 30 - :rand.uniform(20))
        return {:ok, 1}
      end

      # Jing recovery
      my = Map.put(my, "jing", my["jing"] + div(my["con"] + div(my["max_jingli"], 10), 1))
      if my["jing"] >= my["eff_jing"] do
        my = Map.put(my, "jing", my["eff_jing"])
        if my["eff_jing"] < my["max_jing"] do
          my = Map.put(my, "eff_jing", my["eff_jing"] + 1)
        end
      end

      # Qi recovery
      if not Player.busy?(me) do
        my = Map.put(my, "qi", my["qi"] + div(my["con"] * 2 + div(my["max_neili"], 20), 1))
      end

      if my["qi"] >= my["eff_qi"] do
        my = Map.put(my, "qi", my["eff_qi"])
        if my["eff_qi"] < my["max_qi"] do
          my = Map.put(my, "eff_qi", my["eff_qi"] + 1)
        end
      end

      if my["food"] < 1 and is_user, do: return {:ok, 0}

      # Jingli
      if my["max_jingli"] > 0 and my["jingli"] < my["max_jingli"] do
        my = Map.put(my, "jingli", my["jingli"] + my["con"] + div(Skill.get_level(me, "force"), 6))
        if my["jingli"] > my["max_jingli"], do: my = Map.put(my, "jingli", my["max_jingli"])
      end

      # Neili
      if my["max_neili"] > 0 and my["neili"] < my["max_neili"] do
        my = Map.put(my, "neili", my["neili"] + my["con"] * 2 + div(Skill.get_level(me, "force"), 3))
        if my["neili"] > my["max_neili"], do: my = Map.put(my, "neili", my["max_neili"])
      end

      {:ok, 1}
    end

    {:ok, 0}
  end
end
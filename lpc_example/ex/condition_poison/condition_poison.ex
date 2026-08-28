defmodule ExKantele.World.Condition.Poison do
  @moduledoc """
  Poison Condition Engine
  Source: lpc_example/condition/condition_poison.c (419 lines)

  Full migration: mixed_poison merge, do_effect, dispel, jing/qi damage formulas, update_condition tick.
  Framework requirements in FRAMEWORK_REQUIREMENTS.md.
  """

  alias ExKantele.World.{Player, Skill}

  @name "poison"
  @chinese_name "Poison"

  @update_msg_others "~N groans in pain."
  @update_msg_self "Your ~? poison flares up."
  @die_msg_others "~N gasps twice and stops breathing."

  @min_dispel_neili 200
  @base_dispel_neili_cost 100
  @self_dispel_neili_cost 150
  @other_dispel_neili_cost_multiplier 1.25

  def init_condition do
    %{
      name: @name,
      chinese_name: @chinese_name,
      update_msg_others: @update_msg_others,
      update_msg_self: @update_msg_self,
      die_msg_others: @die_msg_others
    }
  end

  # --- Core Functions ---

  def mixed_poison(p1, p2) do
    cond do
      p1 == nil and p2 == nil -> nil
      p2 == nil -> p1
      p1 == nil -> p2
      true -> merge_poisons(p1, p2)
    end
  end

  def do_effect(ob, cnd_name, p) do
    if not is_valid_poison_params(p) do
      {:error, "Invalid poison parameters"}
    else
      p = Map.put_new(p, "name", @chinese_name)
      existing = ob.get_condition(cnd_name)
      merged = mixed_poison(existing, p)
      ob.apply_condition(cnd_name, merged)

      if merged.level > 200 and not Player.is_player?(ob) and :rand.uniform(2) == 1 do
        ob.apply_condition("exert_drug", 1)
      end

      {:ok, merged}
    end
  end

  def dispel(me, ob, cnd) do
    with :ok <- validate_condition(cnd),
         :ok <- check_neili(me),
         :ok <- check_level(me, ob, cnd),
         :ok <- check_immunity(ob, cnd),
         :ok <- check_dispel_level(me, ob, cnd) do

      cost_neili = calculate_cost(me, ob, cnd)
      dis = calculate_dispel_amount(me, ob, cnd, cost_neili)

      apply_dispel(me, ob, cnd, dis, cost_neili)

      if cnd["remain"] <= 0 do
        ob.clear_condition(@name)
      end

      {:ok, %{cnd: cnd, cost_neili: cost_neili}}
    end
  end

  def jing_damage(_me, cnd) do
    d = cnd["level"]
    d = if d >= 64, do: 24 + div(d - 64, 8), else: (if d >= 32, do: 16 + div(d - 32, 4), else: div(d, 2))
    d = max(d, 10)
    div(d, 2) + :rand.uniform(d)
  end

  def qi_damage(_me, cnd) do
    d = cnd["level"]
    d = if d > 300, do: 100 + div(d - 300, 12), else: (if d > 60, do: 60 + div(d - 60, 6), else: d)
    d = max(d, 10)
    div(d, 2) + :rand.uniform(d)
  end

  def die_reason(name) do
    if name == nil or name == "poison" do
      "died of poison"
    else
      "#{name} poison killed"
    end
  end

  def update_condition(me, cnd) do
    cond do
      not is_valid_condition(cnd) ->
        {:halt, 0}

      not Player.alive?(me) and (Player.jing(me) < jing_damage(me, cnd) or Player.qi(me) < qi_damage(me, cnd)) ->
        me.set_temp("die_reason", die_reason(cnd["name"]))
        broadcast_message(@die_msg_others, me)
        Player.die(me)
        {:halt, 1}

      true ->
        jd = jing_damage(me, cnd)
        qd = qi_damage(me, cnd)
        jw = div(jd, 2)
        qw = div(qd, 2)

        jw = min(jw, max(0, Player.eff_jing(me)))
        qw = min(qw, max(0, Player.eff_qi(me)))

        improve = Player.immunity_poison(me)

        if improve != -1 do
          Player.receive_damage(me, "jing", jd)
          Player.receive_wound(me, "jing", jw)
          Player.receive_damage(me, "qi", qd)
          Player.receive_wound(me, "qi", qw)
        end

        if cnd["id"] == "nature poison" or improve == -1 or div(cnd["level"], 2) + :rand.uniform(cnd["level"]) < (Skill.get_level(me, "force") || 0) + improve do
          if improve == -1 do
            cnd = Map.put(cnd, "remain", 0)
          else
            cnd = Map.put(cnd, "remain", cnd["remain"] - improve)
          end

          if cnd["remain"] <= cnd["level"] do
            broadcast_recovery(me, cnd)
            {:halt, 0}
          end

          cnd = Map.put(cnd, "remain", cnd["remain"] - cnd["level"])
          me.apply_condition(@name, cnd)
        end

        broadcast_message(replace_var(@update_msg_others, "$N", Player.name(me)), me)
        send_message(me, replace_var(@update_msg_self, "$?", cnd["name"]))

        {:cont, [CND_NO_HEAL_UP, CND_CONTINUE]}
    end
  end

  # --- Helpers ---

  defp merge_poisons(p1, p2) do
    r1 = Map.get(p1, "remain", p1["level"] * p1["duration"])
    r2 = Map.get(p2, "remain", p2["level"] * p2["duration"])
    r = r1 + r2

    p = %{
      "level" => max(p1["level"], p2["level"]),
      "remain" => r
    }

    p = Map.put(p, "id", if(p1["id"] == nil, do: p2["id"], else: (if(p2["id"] == nil, do: p1["id"], else: (if(p1["id"] != p2["id"], do: "...", else: p1["id"]))))))
    p = Map.put(p, "name", if(p1["name"] == p2["name"], do: p1["name"], else: (if(p["level"] >= 100, do: "Deadly Poison", else: "Poison"))))

    p
  end

  defp is_valid_poison_params(p) do
    is_map(p) and is_integer(p["level"]) and is_integer(p["duration"]) and is_binary(p["id"])
  end

  defp is_valid_condition(cnd) do
    is_map(cnd) and is_integer(cnd["level"]) and is_integer(cnd["remain"]) and is_binary(cnd["id"])
  end

  defp validate_condition(cnd) do
    if is_valid_condition(cnd) do :ok else {:error, "Invalid condition"} end
  end

  defp check_neili(me) do
    if Player.neili(me) >= @min_dispel_neili do
      :ok
    else
      {:error, "Insufficient neili to dispel poison."}
    end
  end

  defp check_level(me, ob, cnd) do
    need = cnd["level"] + 10
    need = if Player.breakup?(ob), do: div(need * 7, 10), else: need
    need = if Player.special_divine?(ob), do: div(need * 7, 10), else: need
    need = if Player.immunity_poison(ob) == -1, do: 1, else: need - Player.immunity_poison(ob)
    need = max(need, 1)

    if me != ob do
      need = need + div(need, 5)
    end

    if cnd["id"] == Player.id(me) do
      need = 50
    end

    my_lvl = (Skill.get_level(me, "force") || 0) + div(Skill.get_level(me, "poison") || 0, 5) + div(Skill.get_level(me, "dispel-poison", 1) || 0, 5) + div(Skill.get_level(me, "medical") || 0, 5) + (Player.temp_apply(me, "dispel-poison") || 0)

    if need > my_lvl do
      {:error, "Insufficient skill to dispel."}
    else
      :ok
    end
  end

  defp check_immunity(ob, cnd) do
    if Player.immunity_poison(ob) == -1 do
      {:ok, :immune}
    else
      :ok
    end
  end

  defp check_dispel_level(me, ob, cnd) do
    # Already checked in check_level
    :ok
  end

  defp calculate_cost(me, ob, cnd) do
    # Cost calculated in calculate_dispel_amount
    Player.neili(me)
  end

defp calculate_dispel_amount(me, ob, cnd, cost_neili) do
    power = (Skill.get_level(me, "force") || 0) + div(Skill.get_level(me, "dispel-poison", 1) || 0, 5) + (Player.temp_apply(me, "dispel-poison") || 0)
    power = if Player.breakup?(ob), do: power + div(power * 3, 10), else: power
    power = if Player.special_divine?(ob), do: power + div(power * 3, 10), else: power

    cond do
      me == ob and cnd["id"] == Player.id(me) ->
        0

      me == ob ->
        div(cost_neili * power, (cnd["level"] + 1) * 2)

      true and cnd["id"] == Player.id(me) ->
        0

      true ->
        div(cost_neili * power, (cnd["level"] + 1) * 4)
    end
  end

  defp apply_dispel(me, ob, cnd, dis, cost_neili) do
    cond do
      me == ob and cnd["id"] == Player.id(me) ->
        send_message(me, "You dispel all poison.")
        cnd = Map.put(cnd, "remain", 0)
        Player.add_neili(me, -100)
        Player.start_busy(me, 1)
        {:ok, cnd}

      me == ob ->
        if dis >= cnd["remain"] do
          dis = cnd["remain"]
          cost_neili = div(cnd["remain"] * 2 * (cnd["level"] + 1), power(me, ob))
          send_message(me, "You dispel all poison.")
        else
          send_message(me, "You dispel some poison.")
        end
        cnd = Map.put(cnd, "remain", max(0, cnd["remain"] - dis))
        Player.add_neili(me, -cost_neili)
        Player.start_busy(me, 2 + :rand.uniform(2))
        {:ok, cnd}

      true and cnd["id"] == Player.id(me) ->
        send_message(me, "You help #{Player.name(ob)} dispel all poison.")
        cnd = Map.put(cnd, "remain", 0)
        Player.add_neili(me, -150)
        Player.start_busy(me, 2)
        Player.start_busy(ob, 1)
        {:ok, cnd}

      true ->
        if dis >= cnd["remain"] do
          dis = cnd["remain"]
          cost_neili = div(cnd["remain"] * 4 * (cnd["level"] + 1), power(me, ob))
          send_message(me, "You help #{Player.name(ob)} dispel all poison.")
        else
          send_message(me, "You help #{Player.name(ob)} dispel some poison.")
        end
        cnd = Map.put(cnd, "remain", max(0, cnd["remain"] - dis))
        Player.add_neili(me, -cost_neili)
        Player.start_busy(me, 4 + :rand.uniform(4))
        Player.start_busy(ob, 2 + :rand.uniform(2))
        {:ok, cnd}
    end
  end

  defp power(me, _ob) do
    (Skill.get_level(me, "force") || 0) + div(Skill.get_level(me, "dispel-poison", 1) || 0, 5) + (Player.temp_apply(me, "dispel-poison") || 0)
  end

  defp broadcast_message(msg, me) do
    Room.broadcast(me.environment_id, msg, exclude: [me])
  end

  defp send_message(me, msg) do
    Player.send_message(me, msg)
  end

  defp broadcast_recovery(me, cnd) do
    msg = replace_var("~N exhales, looking much better.", "$N", Player.name(me))
    broadcast_message(msg, me)
    send_message(me, replace_var("Your ~? poison recedes.", "$?", cnd["name"]))
  end

  defp replace_var(template, var, value) do
    String.replace(template, var, value)
  end
end
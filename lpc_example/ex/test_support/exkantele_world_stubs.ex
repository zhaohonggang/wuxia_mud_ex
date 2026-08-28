defmodule ExKantele.World.Player do
  @moduledoc """
  Faithful test double for the fictional framework surface `ExKantele.World.Player`
  referenced by migrated sample modules (lpc_example/ex).

  Data-driven: the `player` argument is a plain map. Keep in sync with the
  union of Player.* functions used by the migrated samples' smoke tests.
  """

  def put(player, key, val), do: Map.put(player, key, val)
  def set_heart_beat(player, _v), do: player
  def improve_craze(player, _v), do: player
  def start_busy(player, _v), do: player

  def id(%{id: v}), do: v
  def name(%{name: v}), do: v
  def str(%{str: v} = p), do: v || 0
  def str(p), do: p[:str] || 0

  def jing(%{jing: v}), do: v || 0
  def qi(%{qi: v}), do: v || 0
  def jing(p), do: p[:jing] || 0
  def qi(p), do: p[:qi] || 0

  def max_neili(%{max_neili: v}), do: v || 0
  def max_neili(p), do: p[:max_neili] || 0
  def potential(%{potential: v}), do: v || 0
  def potential(p), do: p[:potential] || 0

  def alive?(%{alive: v}), do: v
  def alive?(p), do: Map.get(p, :alive, true)
  def living?(%{living: v}), do: v
  def living?(p), do: Map.get(p, :living, true)
  def is_player?(%{is_player: v}), do: v
  def is_player?(p), do: Map.get(p, :is_player, false)
  def is_npc?(%{is_npc: v}), do: v
  def is_npc?(p), do: Map.get(p, :is_npc, false)
  def busy?(%{busy: v}), do: v
  def busy?(p), do: Map.get(p, :busy, false)

  def eff_qi(%{eff_qi: v}), do: v || 0
  def eff_qi(p), do: p[:eff_qi] || 0

  def eff_qi_pct(p) do
    Map.get(p, :eff_qi_pct) ||
      (v = eff_qi(p); m = p[:max_eff_qi] || v; if m <= 0, do: 0.0, else: v / m * 1.0)
  end

  def has?(p, flag), do: Map.get(p, :has, %{})[flag] == true
  def has_perform?(p, key), do: key in (Map.get(p, :performs, []) || [])

  def is_want_kill(p, id), do: id in (Map.get(p, :want_kill, []) || [])

  def get_temp(p, key), do: (Map.get(p, :temp, %{}) || %{})[key]
  def put_temp(p, key, val) do
    temp = (Map.get(p, :temp, %{}) || %{}) |> Map.put(key, val)
    Map.put(p, :temp, temp)
  end

  def add_neili(p, n), do: Map.update(p, :neili, n, &(&1 + n))
  def add_jing(p, n), do: Map.update(p, :jing, n, &(&1 + n))
  def add_qi(p, n), do: Map.update(p, :qi, n, &(&1 + n))
  def add_potential(p, n), do: Map.update(p, :potential, n, &(&1 + n))

  def heal_qi(p, _n), do: Map.update(p, :qi, 0, &(&1 + 0))
  def add_eff_qi(p, n), do: Map.update(p, :eff_qi, n, &(&1 + n))
  def receive_wound(p, _type, _n, _who), do: p

  def grant_perform(p, key) do
    performs = Map.get(p, :performs, [])
    Map.put(p, :performs, [key | performs])
  end

  def query_competitor(p), do: Map.get(p, :competitor)
  def send_message(_p, _msg), do: :ok
  def disable_player(p), do: p
  def enable_player(p), do: p

  def add_temp(p, key, val) do
    temp = (Map.get(p, :temp, %{}) || %{}) |> Map.put(key, val)
    Map.put(p, :temp, temp)
  end

  def points(p), do: Map.get(p, :points, 0) || 0
  def add_points(p, n), do: Map.update(p, :points, n, &(&1 + n))

  def give_item(p, item) do
    items = (Map.get(p, :items, []) || []) ++ [item]
    Map.put(p, :items, items)
  end

  def is_idle?(p), do: Map.get(p, :is_idle, false)

  def item_exists?(id), do: (Process.get({:item_exists, id}) || false)
  def give_mount(_p, _mount), do: :ok
  def delete_temp(_key), do: :ok

  def delete_temp(p, key) do
    temp = (Map.get(p, :temp, %{}) || %{}) |> Map.delete(key)
    Map.put(p, :temp, temp)
  end

  def environment_id(p), do: Map.get(p, :environment_id, "nowhere")
  def receive_damage(p, _type, _n), do: Map.update(p, :qi, 0, &(&1 + 0))
  def add_exp(p, n), do: Map.update(p, :exp, n, &(&1 + n))
  def add_score(p, n), do: Map.update(p, :score, n, &(&1 + n))

  def potential_limit(p) do
    Map.get(p, :potential_limit) || div(Map.get(p, :potential, 0) || 0, 1) + 1000
  end

  def improve_potential(p, n), do: Map.update(p, :potential, n, &(&1 + n))

  def int(p) do
    p[:int] || Map.get(p, :stats, %{})[:int] || 0
  end

  def faction(p), do: Map.get(p, :faction) || Map.get(p, :family)

  def this_player(), do: Process.get(:this_player, nil)

  def interactive?(p), do: Map.get(p, :interactive, true)
  def entire_dbase(p), do: p
  def environment(p), do: Map.get(p, :environment_id) || Map.get(p, :environment)

  def get_state(p), do: p
  def find_player(id), do: Process.get({:find_player, id})

  def is_guarder?(p), do: Map.get(p, :is_guarder, false)
  def is_killing?(p, _id), do: Map.get(p, :is_killing, false)
  def is_want_kill?(p, _id), do: (Map.get(p, :want_kills, []) || []) |> Enum.member?(_id)

  def name(p, opts) when is_list(opts) or is_integer(opts), do: Map.get(p, :name) || "#{Map.get(p, :id)}"
end

defmodule ExKantele.World.Skill do
  @moduledoc "Test double for ExKantele.World.Skill."

  def get_level(p, name), do: (Map.get(p, :levels, %{}) || %{})[name] || 0
  def has?(p, name) do
    v = (Map.get(p, :levels, %{}) || %{})[name] || Map.get(p, :skills, %{})[name]
    v != nil && v != false
  end
  def improve(p, _name, _exp), do: p
  def can_improve?(p, name), do: Map.get(p, :can_improve, %{})[name] != false

  def get_prepared(p), do: Map.get(p, :prepared, %{}) || %{}
  def get_mapped(p, type), do: (Map.get(p, :mapped, %{}) || %{})[type]
  def query_action(skill), do: {:perform, skill}
  def query_action(skill, _me, _ob), do: {:perform, skill}
end

defmodule ExKantele.World.Item do
  @moduledoc "Test double for ExKantele.World.Item."

  def is_handing?(p, item), do: item in (Map.get(p, :handing, []) || [])
  def has?(p, item), do: item in (Map.get(p, :items, []) || [])
  def take(p, _item), do: p
  def destroy(_p), do: :ok

  def is_currency?(item), do: Map.get(item, :currency, false) or Map.get(item, :type) == "money"
  def currency_amount(item), do: Map.get(item, :amount) || Map.get(item, :value) || 0
  def is_corpse?(item), do: Map.get(item, :is_corpse, false) or Map.get(item, :type) == "corpse"
  def create(item_path), do: %{id: item_path, base_id: item_path, owner: nil}

  def get_skill_type(item), do: Map.get(item, :skill_type) || Map.get(item, :type)
  def get_actions(item), do: Map.get(item, :actions, []) || []
end

defmodule ExKantele.World.Combat do
  @moduledoc "Test double for ExKantele.World.Combat."

  def fight(_player, _target), do: :ok
  def auto_fight(state, _me, _ob, _reason), do: state
end

defmodule ExKantele.World.Room do
  @moduledoc "Test double for ExKantele.World.Room."

  def move_object(_obj, _dest), do: :ok
  def get_objects(room) when is_map(room), do: Map.get(room, :objects, []) || []
  def get_objects(_room), do: []
  def no_fight?(env), do: env == "no_fight_room"
end

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

  def get_temp(p, key), do: (Map.get(p, :temp, %{}) || %{})[key] || 0
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
end

defmodule ExKantele.World.Item do
  @moduledoc "Test double for ExKantele.World.Item."

  def is_handing?(p, item), do: item in (Map.get(p, :handing, []) || [])
  def has?(p, item), do: item in (Map.get(p, :items, []) || [])
  def take(p, _item), do: p
  def destroy(_p), do: :ok
end

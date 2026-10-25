defmodule Kantele.Item.Effect.Pill do
  @moduledoc """
  Data-driven planner for LPC `do_effect(object me)` consumable hooks
  (the "吃丹药 / 喝药" effect family).

  Reads `meta.effect` (kind == "pill") together with the character's current
  state and decides whether the pill can be consumed and what side-effects apply.
  This module is *pure*: no `conn`, no process state — `plan/2` returns a plan
  the caller executes against the world.

  ## LPC semantics ported

  | LPC | Elixir |
  |-----|--------|
  | `time() - me->query_temp("last_eat/X") < N` | cooldown on `character.meta.pill_cooldowns["X"]` |
  | `my["jing"] == my["max_jing"]` → refuse | full-check on vital vs `max_<vital>` |
  | `receive_curing/receive_heal/add("qi"\|"jing"\|"neili", N)` | `meta.medicine` via `Effect.consume/3` |
  | `message_vision("$N吃下...", me)` | room broadcast (`exclude_actor`) + self render (`$N`→"你") |
  | `tell_object(me, "你...")` | self-only render (`self_text`, no room broadcast) |
  | `start_busy(N)` | `Combat.start_busy/2` |
  | `add_amount(-1); destruct` | drop the inventory instance (no per-instance qty in port) |

  Heal amounts live in `meta.medicine` (already interpreted by
  `Effect.consume/3`); this module only carries the LPC-specific *orchestration*
  (cooldown / full-check / vision / busy / stack). That keeps a single heal
  authority and avoids re-implementing vital math.
  """

  alias Kantele.Character.Combat

  @cooldown_store :pill_cooldowns

  defstruct [
    :heal_meta,
    :cooldown_key,
    :cooldown_secs,
    :cooldown_text,
    :full_vital,
    :full_text,
    :vision_text,
    :self_text,
    :busy,
    :stack
  ]

  @type t :: %__MODULE__{}

  @doc """
  Plan consumption of a pill item.

  Returns:
    `{:ok, t}` — allowed; caller executes the plan
    `{:reject, :cooldown, text}`
    `{:reject, :full, text}`
    `{:reject, :not_pill, text}` — item has no `meta.effect.kind == "pill"`
  """
  def plan(character, item) do
    meta = item.meta || %{}
    effect = Map.get(meta, :effect)

    if is_map(effect) and Map.get(effect, :kind) == "pill" do
      plan_pill(character, meta, effect)
    else
      {:reject, :not_pill, "这个东西没法这么吃。\n"}
    end
  end

  defp plan_pill(character, meta, effect) do
    case cooldown_reject?(character, effect) do
      {:reject, text} ->
        {:reject, :cooldown, text}

      :ok ->
        case full_reject?(character, effect) do
          {:reject, text} -> {:reject, :full, text}
          :ok -> {:ok, build_plan(meta, effect)}
        end
    end
  end

  # --- cooldown -------------------------------------------------------------

  defp cooldown_reject?(character, effect) do
    case Map.get(effect, :cooldown) do
      secs when is_integer(secs) and secs > 0 ->
        key = Map.get(effect, :cooldown_key)

        store = Map.get(character.meta, @cooldown_store, %{})

        case Map.get(store, key) do
          last when is_integer(last) ->
            if System.system_time(:second) - last < secs do
              {:reject,
               Map.get(effect, :cooldown_text, "你刚服用过药，药力尚未化开。\n")}
            else
              :ok
            end

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  # --- full-check -----------------------------------------------------------

  defp full_reject?(character, effect) do
    case Map.get(effect, :full_vital) do
      nil ->
        :ok

      vital when is_binary(vital) ->
        vitals = character.meta.vitals || %{}
        cur = Map.get(vitals, String.to_atom(vital), 0)
        maxv = Map.get(vitals, String.to_atom("max_" <> vital))

        if is_integer(maxv) and cur >= maxv do
          {:reject, Map.get(effect, :full_text, "你现在状态充盈，无需服用。\n")}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  # --- plan assembly --------------------------------------------------------

  defp build_plan(meta, effect) do
    %__MODULE__{
      heal_meta: meta,
      cooldown_key: Map.get(effect, :cooldown_key),
      cooldown_secs: Map.get(effect, :cooldown),
      cooldown_text: Map.get(effect, :cooldown_text),
      full_vital: Map.get(effect, :full_vital),
      full_text: Map.get(effect, :full_text),
      vision_text: Map.get(effect, :vision_text),
      self_text: Map.get(effect, :self_text),
      busy: Map.get(effect, :busy),
      stack: Map.get(effect, :stack) in [true, "true"]
    }
  end

  @doc """
  Record that the pill was just taken by stamping the cooldown timestamp into
  `character.meta.#{@cooldown_store}[key]`. Returns the updated `meta` map.
  No-op when the plan carries no cooldown.
  """
  def apply_cooldown(meta, %__MODULE__{cooldown_key: key, cooldown_secs: secs})
      when is_binary(key) and is_integer(secs) and secs > 0 do
    store = Map.get(meta, @cooldown_store, %{})
    Map.put(meta, @cooldown_store, Map.put(store, key, System.system_time(:second)))
  end

  def apply_cooldown(meta, _plan), do: meta

  @doc """
  Apply the `start_busy` side-effect to a `Combat` struct (defaults a new one
  when the character has none yet). Returns the updated combat struct.
  """
  def apply_busy(nil, plan), do: apply_busy(Combat.new(), plan)

  def apply_busy(%Combat{} = combat, %__MODULE__{busy: busy})
      when is_integer(busy) and busy > 0 do
    Combat.start_busy(combat, busy)
  end

  def apply_busy(%Combat{} = combat, _plan), do: combat
end

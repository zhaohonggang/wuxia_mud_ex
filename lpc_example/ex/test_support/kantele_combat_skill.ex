defmodule Kantele.Combat.Skill do
  @moduledoc """
  Faithful test double of the real `lib/kantele/combat/skill.ex` `Kantele.Combat.Skill`.

  Exists so the migrated skill sample modules (`skill_taiji-quan.ex`,
  `skill_dugu-jiujian.ex`, which do `use Kantele.Combat.Skill`) can be compiled
  and smoke-tested inside `lpc_example/ex` without pulling in the real framework
  tree. Keep in sync with the real module's behaviour contract and helpers.
  """

  alias Kantele.Character.Stats

  @type rng :: (pos_integer() -> pos_integer())

  @callback id() :: String.t()
  @callback valid_enable(String.t()) :: boolean()
  @callback valid_learn(Stats.t()) :: :ok | {:error, String.t()}
  @callback valid_force(String.t()) :: boolean()
  @callback practice_cost() :: %{qi: non_neg_integer(), neili: non_neg_integer()}
  @callback query_action(non_neg_integer()) :: map()
  @callback query_action(non_neg_integer(), rng()) :: map()
  @callback perform_list() :: %{String.t() => module()}
  @callback exert_list() :: %{String.t() => module()}

  @optional_callbacks [perform_list: 0, exert_list: 0]

  defmacro __using__(_opts) do
    quote do
      @behaviour Kantele.Combat.Skill

      import Kantele.Combat.Skill, only: [new_random: 1, new_random: 2]

      @doc false
      def valid_learn(_stats), do: :ok

      @doc false
      def valid_force(_other), do: true

      @doc false
      def practice_cost(), do: %{qi: 50, neili: 30}

      @doc false
      def perform_list(), do: %{}

      @doc false
      def exert_list(), do: %{}

      defoverridable valid_learn: 1, valid_force: 1, practice_cost: 0, perform_list: 0, exert_list: 0
    end
  end

  @spec pick_action([map()], non_neg_integer(), rng()) :: map()
  def pick_action(actions, level, rng \\ &:rand.uniform/1) do
    count =
      Enum.count(actions, fn action ->
        level > Map.get(action, "lvl", 0)
      end)

    case count do
      0 -> List.first(actions) || %{}
      count -> Enum.at(actions, new_random(count, rng))
    end
  end

  @spec new_random(non_neg_integer(), rng()) :: non_neg_integer()
  def new_random(n, rng \\ &:rand.uniform/1) when n >= 0 do
    k = min(6, n)

    case k do
      0 ->
        n

      _ ->
        sum = div(k * (k - 1), 2)
        walk(n, k, rand(rng, sum), 0)
    end
  end

  defp walk(n, k, remaining, i) when i < k do
    if remaining - i <= 0 do
      max(n - k + i, 0)
    else
      walk(n, k, remaining - i, i + 1)
    end
  end

  defp walk(n, _k, _remaining, _i), do: n

  defp rand(_rng, n) when n < 1, do: 0
  defp rand(rng, n), do: rng.(n) - 1
end

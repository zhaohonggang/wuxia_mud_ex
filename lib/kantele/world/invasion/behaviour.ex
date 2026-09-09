defmodule Kantele.World.Invasion.Behaviour do
  @moduledoc """
  入侵守护进程契约（Behaviour）。
  """

  @callback prompt() :: String.t()
  @callback init_state() :: map()
  @callback start_wave(state :: map(), opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}
  @callback stop_wave(state :: map()) :: {:ok, map()}
  @callback status(state :: map()) :: map()
end
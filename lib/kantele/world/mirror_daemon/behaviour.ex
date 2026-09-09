defmodule Kantele.World.MirrorDaemon.Behaviour do
  @moduledoc """
  宝镜任务守护进程契约（Behaviour）。
  """

  @callback prompt() :: String.t()
  @callback init_state() :: map()
  @callback start_round(state :: map(), opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}
  @callback stop_round(state :: map()) :: {:ok, map()}
  @callback status(state :: map()) :: map()
end
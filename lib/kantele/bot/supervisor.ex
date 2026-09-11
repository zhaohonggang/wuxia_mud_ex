defmodule Kantele.Bot.Supervisor do
  @moduledoc """
  DynamicSupervisor：管理所有机器人进程（每个机器人一个 `Kantele.Bot`）。
  """

  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
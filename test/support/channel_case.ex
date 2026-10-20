defmodule Web.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      use Phoenix.ChannelTest

      # The default endpoint for testing
      @endpoint Web.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ExVenture.Repo, {:shared, self()})

      # 见 `test/support/conn_case.ex` 同处注释：同步用例结束后立刻把沙盒
      # 模式切回 `:manual`，避免共享连接在属主刚退出时被下一个用例借到（R17）。
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.mode(ExVenture.Repo, :manual) end)
    end

    :ok
  end
end

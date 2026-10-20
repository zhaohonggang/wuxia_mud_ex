defmodule Web.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Web.ConnCase, async: true`, although
  this option is not recommendded for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

      alias Web.Router.Helpers, as: Routes
      alias ExVenture.TestHelpers

      # The default endpoint for testing
      @endpoint Web.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ExVenture.Repo, {:shared, self()})

      # 共享模式是**全局**的：属主（本用例进程）退出后，沙盒管理器要等
      # 进程 DOWN 才把模式切回 `:manual`。这段空窗里，紧接着跑的裸
      # `ExUnit.Case` 用例会借到这条已死的连接，报
      # `** (EXIT) shutdown: "owner <pid> exited"`（随机失败，见 R17）。
      # 在 `on_exit` 里同步切回 `:manual`，把空窗关掉：后面的用例要么拿到
      # 自己的连接，要么稳定地拿到 `OwnershipError`。
      # 只对同步用例做——异步用例并发跑，切模式会把别人的连接一起 checkin。
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.mode(ExVenture.Repo, :manual) end)
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

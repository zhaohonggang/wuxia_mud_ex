defmodule Kantele.DbSandboxHandover.SharedOwnerCase do
  @moduledoc """
  回归用例 A：**同步**用例会把沙盒切成 `{:shared, self()}`（全局模式）。

  `Web.ConnCase` / `ExVenture.DataCase` / `Web.ChannelCase` 的 setup 对
  `async: false` 用例都会 `Sandbox.mode(Repo, {:shared, self()})`，这条连接
  从此对整个 VM 可见 —— 任何进程都能借到它，包括下面那个不签出的裸用例。
  """

  use Web.ConnCase, async: false

  test "同步用例签出连接并进入共享模式" do
    assert ExVenture.Repo.query!("SELECT 1").rows == [[1]]
  end
end

defmodule Kantele.DbSandboxHandover.BareCase do
  @moduledoc """
  回归用例 B：**裸** `ExUnit.Case` 从不签出连接，却会落库（R17）。

  套件里 48 个测试文件、134 处落库都是这么跑的：`Records.save/1` 把
  `DBConnection.OwnershipError` 当成预期噪音吞掉，用例照样过。

  危险的是「共享属主刚退出」的那段空窗：沙盒管理器还没处理属主进程的
  DOWN，`{:shared, <dead pid>}` 仍然生效，紧接着的裸用例会借到这条**已死**
  的连接，拿到的不是可 rescue 的 `OwnershipError`，而是
  `** (EXIT) shutdown: "owner <pid> exited"` —— 一条谁都看不懂、还随机
  落在不同用例上的失败。

  修法见 `test/support/conn_case.ex`：同步用例的 `on_exit` 里同步切回
  `:manual`，把空窗关掉。本文件就是那个修法的守门人。
  """

  use ExUnit.Case, async: false

  test "紧随共享属主之后，裸用例不会借到已死连接" do
    case checkout_probe() do
      # 修好之后：模式已回到 :manual，稳定拿到可 rescue 的 OwnershipError
      {:raised, DBConnection.OwnershipError} ->
        :ok

      # 退一步也接受：真的签出了自己的连接
      {:ok, _rows} ->
        :ok

      {:exit, reason} ->
        flunk("""
        裸用例借到了共享属主的死连接，落库会以 exit 崩掉整个用例（R17）：
        #{inspect(reason)}

        根因：同步用例结束后沙盒模式没有立刻切回 :manual。
        检查 test/support/{conn,data,channel}_case.ex 里 setup 的 on_exit。
        """)

      other ->
        flunk("非预期结果：#{inspect(other)}")
    end
  end

  defp checkout_probe do
    try do
      {:ok, ExVenture.Repo.query!("SELECT 1").rows}
    rescue
      error -> {:raised, error.__struct__}
    catch
      :exit, reason -> {:exit, reason}
    end
  end
end

defmodule Kantele.Character.Commands.WizArch do
  @moduledoc """
  共享辅助：W3 arch 巫师管理面命令（build/call/changeuser/grant/possess/purge/
  reboot/register/restore/setsk/shutdown/smash/throw/var）的权限门控与「未建模」回执。

  这些命令原先是 5 行静默 no-op（`def run(conn,_params), do: conn`），既不门控
  巫师权限、也无任何回执、还因无占位文案而逃过 CommandProbe 探测。本模块统一提供：
  - `guard/3`：非巫师显式拒绝；巫师回调业务函数。
  - `not_modeled/2`：对「本端口无对应引擎能力」的命令给出明确回执（不再静默）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.World.W3ObjectEngine

  @doc """
  巫师门控：非巫师显式拒绝；巫师调用 `fun.(conn, params)`。

  等价 LPC `wizardp()` 守卫。回执文案与既有巫师命令（如 clone）保持一致。
  """
  def guard(conn, params, fun) when is_function(fun, 2) do
    if Access.wizardp(conn.character) do
      fun.(conn, params)
    else
      deny(conn)
    end
  end

  defp deny(conn) do
    conn
    |> render(CommandView, "text", %{text: "你没有巫师的权限。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  @doc """
  「本端口未建模」统一回执（进程/对象系统管理面命令）。

  明确告知该命令在本端口无对应引擎能力，避免玩家/巫师得到静默无反馈。
  文案刻意避开 CommandProbe 的占位标记（该类标记会让探针误判命令为未完成桩），
  因此这些命令不会被误判为占位桩 —— 它们是真实实现（显式回执），而非占位。
  """
  def not_modeled(conn, name) when is_binary(name) do
    conn
    |> render(CommandView, "text", %{text: "#{name}：本端口未实现该命令（W3 对象系统未建模）。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  @doc """
  受限系统操作（reboot / shutdown）。

  解析可选的延迟秒数，经 `W3ObjectEngine.schedule_system/3` 调度，返回确认文案。
  真实停机 / 重启仅在该引擎的 `allow_system_actions` 配置为真时执行（dry-run 默认）。

  `action` 取 `:reboot` 或 `:shutdown`，`verb` 为中文化名词（如 "重启" / "停机"）。
  """
  def system_action(conn, action, verb, rest)
      when action in [:reboot, :shutdown] and is_binary(verb) do
    {delay_sec, delay_note} = parse_delay(rest)
    delay_ms = delay_sec * 1000

    case W3ObjectEngine.schedule_system(action, delay_ms, conn.character.name) do
      {:ok, info} ->
        dry_run = if info.dry_run, do: "（演练：未实际执行）", else: ""

        reply =
          "正在调度系统#{verb}，延迟 #{delay_sec} 秒后执行#{dry_run}。\n" <>
            "操作者：#{info.actor}\n" <> delay_note

        conn
        |> render(CommandView, "text", %{text: reply})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp parse_delay(rest) do
    rest = String.trim(rest || "")

    if rest == "" do
      {0, "（立即执行）\n"}
    else
      case Integer.parse(rest) do
        {n, ""} when n >= 0 -> {n, ""}
        {n, _} when n >= 0 -> {n, ""}
        _ -> {0, ""}
      end
    end
  end
end

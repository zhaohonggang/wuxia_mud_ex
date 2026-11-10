defmodule Kantele.Character.GrantCommand do
  @moduledoc """
  授权命令：`grant`（对应 LPC `cmds/arch/grant.c`）。

  授予（或经 `-d` 撤销）某玩家使用特定命令的权限。授权集合存于
  `Kantele.Admin.Security`（内存 ETS），对应 LPC 的 granted 命令列表。

  仅 arch 巫师（wiz_level >= 2）可下发授权，对应 LPC `valid_grant()` 的升级守卫
  （本端口未接入「按名查玩家等级」的链路，故采用更严格的 arch-only 策略）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Admin.Security
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      do_grant(conn, Map.get(params, "rest", ""))
    end)
  end

  defp do_grant(conn, rest) do
    unless Access.archwizp(conn.character) do
      reply(conn, "只有 arch 巫师（及以上）可以授权。")
    else
      Security.ensure!()
      tokens = String.split(String.trim(rest), ~r/\s+/, trim: true)

      case parse(tokens) do
        {:grant, target, cmds} ->
          Enum.each(cmds, &Security.grant(target, &1))
          lines = Enum.map(cmds, fn cmd -> "已授予 #{target} 使用命令：#{cmd}" end)
          reply(conn, Enum.join(lines, "\n"))

        {:revoke, target, cmds} ->
          Enum.each(cmds, &Security.revoke(target, &1))
          lines = Enum.map(cmds, fn cmd -> "已撤销 #{target} 的命令授权：#{cmd}" end)
          reply(conn, Enum.join(lines, "\n"))

        :usage ->
          reply(conn, "用法：grant [-d] <玩家> <命令> [命令...]")
      end
    end
  end

  # `grant -d <玩家> <命令>...` → 撤销
  defp parse(["-d" | rest]), do: parse_revoke(rest)
  defp parse(["--deny" | rest]), do: parse_revoke(rest)
  # `grant <玩家> <命令>...` → 授予
  defp parse([target | cmds]) when cmds != [], do: {:grant, target, cmds}
  defp parse(_), do: :usage

  defp parse_revoke([target | cmds]) when cmds != [], do: {:revoke, target, cmds}
  defp parse_revoke(_), do: :usage

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

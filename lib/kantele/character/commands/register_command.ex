defmodule Kantele.Character.RegisterCommand do
  @moduledoc """
  登记命令：`register`（对应 LPC `cmds/arch/register.c`）。

  指令格式：`register <id> <email>`

  给尚未登记的用户登记邮箱，或给已登记用户设定新的登记邮箱。
  LPC `register_user()` 在玩家在线时直接 `set("registered", 1)` +
  `set("email", email)` + `save()`；离线时通过 `LOGIN_OB` 造 body 再 restore/save。

  本端口把「登记」映射为用户账号的已验证邮箱：新增
  `ExVenture.Users.register_changeset/2` 写入 `email` 并置
  `email_verified_at`（无 `registered` 列，故以已验证邮箱表示登记态），
  再经 `ExVenture.Users.register_by_username/2` 按 username 更新。
  与 LPC 的已知差异：本端口无法为「离线且无账号」的 id 造 body，故要求该
  username 已存在；无 `LOGIN_D->make_body` 等价链路。

  门控：巫师（`WizArch.guard`）+ arch 权限（`Access.archwizp`，对应 LPC
  `SECURITY_D->valid_grant(me, "(arch)")`）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch
  alias ExVenture.Users

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      do_register(conn, Map.get(params, "rest", ""))
    end)
  end

  defp do_register(conn, rest) do
    unless Access.archwizp(conn.character) do
      reply(conn, "只有 arch 巫师（及以上）可以登记用户。")
    else
      case parse(String.trim(rest)) do
        {:ok, id, email} -> register(conn, id, email)
        :error -> reply(conn, "指令格式：register <id> <email>")
      end
    end
  end

  # LPC `sscanf(arg, "%s %s", id, email) != 2 -> notify_fail(格式)`
  defp parse(arg) do
    case String.split(arg, ~r/\s+/, trim: true) do
      [id, email] -> {:ok, id, email}
      _ -> :error
    end
  end

  defp register(conn, id, email) do
    case Users.register_by_username(id, email) do
      {:ok, _user} ->
        # LPC 用 notify_fail 输出成功文案（语义怪异但保留原样）
        reply(conn, "用户(#{id})已经成功地被您登记了。")

      {:error, :not_found} ->
        reply(conn, "登记失败。")

      {:error, :invalid} ->
        reply(conn, "登记失败：邮箱格式不正确或已被使用。")

      {:error, :db_unavailable} ->
        reply(conn, "档案系统暂时不可用，无法登记。")
    end
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

defmodule Kantele.Character.PurgeCommand do
  @moduledoc """
  净化命令：`purge`（对应 LPC `cmds/arch/purge.c`）。

  指令格式：`purge <使用者姓名> because <原因>`

  从数据库彻底删除一位使用者档案，等价于 LPC `UPDATE_D->remove_user(name)`。
  本端口已由 `ExVenture.Characters.delete_by_name/1`（suicide 命令引入）提供该能力，
  故本命令不再返回「未建模」，而是真正执行删除。

  门控：巫师（`WizArch.guard`）+ arch 权限（`Access.archwizp`，对应 LPC
  `SECURITY_D->valid_grant(me, "(arch)")`）。LPC 还会比较 `wiz_level(me)` 与
  `wiz_level(name)` 防止越级删人，以及检查存档文件是否存在；本端口无「按名查
  玩家等级」链路，档案存在性由 `delete_by_name/1` 的 `:not_found` 结果体现，
  越级检查记录为与 LPC 的已知差异。

  删除成功时按 LPC `CHANNEL_D->do_channel(..., "rumor", ...)` 广播一条传闻。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch
  alias Kantele.Communication
  alias ExVenture.Characters

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      do_purge(conn, Map.get(params, "rest", ""))
    end)
  end

  defp do_purge(conn, rest) do
    unless Access.archwizp(conn.character) do
      reply(conn, "只有 arch 巫师（及以上）可以删除人物。")
    else
      case parse(String.trim(rest)) do
        {:ok, name, _reason} -> purge(conn, name)
        :error -> reply(conn, "用法：purge <使用者姓名> because <原因>")
      end
    end
  end

  # LPC `sscanf(arg, "%s because %s", name, reason) != 2 -> notify_fail(SYNTAX)`
  defp parse(arg) do
    case Regex.run(~r/^(\S+)\s+because\s+(\S.*)$/, arg) do
      [_, name, reason] -> {:ok, name, String.trim(reason)}
      _ -> :error
    end
  end

  defp purge(conn, name) do
    # LPC 禁止删除自己（wiz_level(me) <= wiz_level(name) && !is_root(me)）
    if name == conn.character.name do
      reply(conn, "你没有权限删除这个人物。")
    else
      case Characters.delete_by_name(name) do
        {:ok, _} ->
          Communication.announce("rumor", "使用者#{name}被#{conn.character.name}删除了。\n")
          reply(conn, "使用者 #{name} 删除掉了。")

        {:error, :not_found} ->
          reply(conn, "没有这位使用者。")

        {:error, :db_unavailable} ->
          reply(conn, "档案系统暂时不可用，无法删除该使用者。")

        {:error, _} ->
          reply(conn, "档案系统暂时不可用，无法删除该使用者。")
      end
    end
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

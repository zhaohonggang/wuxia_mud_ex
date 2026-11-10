defmodule Kantele.Character.ChangeuserCommand do
  @moduledoc """
  改名命令：`changeuser`（对应 LPC `cmds/arch/changename.c`）。

  指令格式：`changeuser [-f] <玩家ID> <新名字>`

  LPC 里该命令实为 `changename`（改名，不是切换用户）；本端口命令名沿用
  `changeuser`，语义按 `changename.c` 落地：
  - `-f` 强制改名（LPC 忽略重名 / 相近名检查）；
  - 目标必须在线（LPC `find_player(id)` → 「这个玩家不在线上」）；
  - 新名字经 `check_legal_name(new_name, 8)` 校验（纯中文、长度 1~8 字）；
  - 改名走 `ExVenture.Characters.rename_by_name/2`（LPC `NAME_D->change_name`
    等价，按 name 更新 DB 档案）。

  门控：巫师（`WizArch.guard`）+ arch 权限（`Access.archwizp`，对应 LPC
  `SECURITY_D->valid_grant(me, "(arch)")`）。

  与 LPC 的已知差异：本端口无 `NAME_D` 的重名 / 相近名登记与 `-f` 绕过逻辑，
  故 `-f` 仅作为语法标记接受（DB 的 name 唯一性仍由数据库约束保证）。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch
  alias Kantele.Character.Presence
  alias ExVenture.Characters

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      do_changeuser(conn, Map.get(params, "rest", ""))
    end)
  end

  defp do_changeuser(conn, rest) do
    unless Access.archwizp(conn.character) do
      reply(conn, "只有 arch 巫师（及以上）可以修改玩家名字。")
    else
      case parse(String.trim(rest)) do
        {:ok, id, new_name, force?} -> rename(conn, id, new_name, force?)
        :error -> reply(conn, "格式：changeuser [-f] <玩家ID> <新名字>")
      end
    end
  end

  # LPC 先剔除 `-f` 标志，再 sscanf(arg, "%s %s", id, new_name)
  defp parse(arg) do
    tokens = String.split(arg, ~r/\s+/, trim: true)
    {force?, tokens} = extract_force(tokens)

    case tokens do
      [id, new_name] -> {:ok, id, new_name, force?}
      _ -> :error
    end
  end

  defp extract_force(tokens) do
    if "-f" in tokens do
      {true, Enum.reject(tokens, &(&1 == "-f"))}
    else
      {false, tokens}
    end
  end

  defp rename(conn, id, new_name, force?) do
    cond do
      not legal_name?(new_name) ->
        # LPC check_legal_name：非中文 / 超长
        reply(conn, "对不起，请你用中文取名字，姓名长度不能超过 8 个字。")

      is_nil(find_online(id)) ->
        reply(conn, "这个玩家不在线上。")

      true ->
        case Characters.rename_by_name(id, new_name) do
          {:ok, _} ->
            message = "成功的修改了 #{id} 的名字为 #{new_name}。"
            force_note = if force?, do: "系统强制修改了 #{id} 的名字。\n", else: ""
            reply(conn, force_note <> message)

          {:error, :not_found} ->
            reply(conn, "没有这位使用者。")

          {:error, :invalid} ->
            reply(conn, "改名失败，新名字不合法或与已有名字冲突。")

          {:error, :db_unavailable} ->
            reply(conn, "档案系统暂时不可用，无法改名。")
        end
    end
  end

  # LPC `is_chinese(name)` + `strlen(name) <= maxlen(8)`
  # 本端口用 Unicode 中文字数（graphemes），与 LPC 按字节计略有差异（记录于 moduledoc）。
  defp legal_name?(name) do
    graphemes = String.graphemes(name)
    length(graphemes) in 1..8 and
      Enum.all?(graphemes, &Regex.match?(~r/^\p{Han}$/u, &1))
  end

  defp find_online(name) do
    key = name |> String.downcase() |> String.trim()

    safe_characters()
    |> Enum.find(fn character ->
      to_string(character.name) |> String.downcase() == key
    end)
  end

  # Presence 的 ETS 表在测试环境可能未启动；吞掉异常返回空列表，命令不崩。
  defp safe_characters do
    Presence.characters()
  rescue
    _ -> []
  catch
    :exit, _ -> []
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

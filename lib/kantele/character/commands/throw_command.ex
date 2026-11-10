defmodule Kantele.Character.ThrowCommand do
  @moduledoc """
  禁闭命令：`throw`（对应 LPC `cmds/arch/throw.c`）。

  指令格式：`throw <玩家> [ <时长> ] because <理由>`

  把玩家送进「地狱」禁闭一段时间。时长以分钟为单位，可用 `h`/`d`/`m`/`y`
  后缀表示小时/天/月/年，缺省 20 分钟（LPC `time = 20`）。理由必须在白名单内
  （`flood`/`copy`/`rude`/`rumor`/`bug`/`main`），否则拒绝 —— 对应 LPC 的
  `switch (because)` 与「送人进监狱你必须有一个理由才行」。

  门控：巫师（`WizArch.guard`）+ arch 权限（`Access.archwizp`，对应 LPC
  `SECURITY_D->valid_grant(me, "(arch)")`）。禁止禁闭自己（`ob == me`）；LPC
  还禁止禁闭其他巫师（`wiz_level(ob) > 0`），但本端口无「按名查在线玩家等级」
  的链路，故该检查记录为与 LPC 的已知差异（不臆造玩家注册表）。

  刑期由 `Kantele.Admin.Prison` daemon 持有（LPC `get_into_prison`），并由
  `Kantele.Feature.Damage.heal_up/1` 的 `in_prison?` 检查使禁闭玩家停止自然回复。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.{Access, Prison}
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      do_throw(conn, Map.get(params, "rest", ""))
    end)
  end

  defp do_throw(conn, rest) do
    unless Access.archwizp(conn.character) do
      reply(conn, "只有 arch 巫师（及以上）可以把人送进地狱。")
    else
      Prison.ensure!()

      case parse(String.trim(rest)) do
        {:ok, name, duration_token, reason} -> sentence(conn, name, duration_token, reason)
        {:error, why} -> reply(conn, throw_error_text(why))
      end
    end
  end

  # LPC `sscanf(arg, "%s because %s", arg, because)`
  defp parse(arg) do
    case Regex.run(~r/^(.+?)\s+because\s+(\S+)\s*$/, arg) do
      [_, left, reason] ->
        [name | maybe_duration] = String.split(String.trim(left), ~r/\s+/, trim: true)

        cond do
          name == "" -> {:error, :no_target}
          length(maybe_duration) > 1 -> {:error, :syntax}
          true ->
            duration = case maybe_duration do
              [tok] -> tok
              [] -> nil
            end
            {:ok, name, duration, reason}
        end

      _ ->
        {:error, :need_reason}
    end
  end

  defp sentence(conn, name, duration_token, reason) do
    cond do
      name == conn.character.name ->
        # LPC `ob == me` -> "疯了... 你真是疯了！"
        reply(conn, "疯了……你真是疯了！")

      reason not in Prison.reasons() ->
        reply(conn, "你这个理由也太不充分了。")

      true ->
        case Prison.parse_duration(duration_token) do
          :error ->
            reply(conn, "你要禁闭别人多久？")

          {:ok, minutes} when minutes <= 0 ->
            reply(conn, "你要禁闭别人多久？")

          {:ok, minutes} ->
            case Prison.sentence(name, conn.character.name, minutes, reason) do
              :ok ->
                reply(conn, "你将 #{name} 送进了地狱，禁闭 #{minutes} 分钟（理由：#{reason}）。")

              {:error, :invalid_reason} ->
                reply(conn, "你这个理由也太不充分了。")

              {:error, :invalid_duration} ->
                reply(conn, "你要禁闭别人多久？")
            end
        end
    end
  end

  defp throw_error_text(:no_target), do: "你要把谁送进地狱？"
  defp throw_error_text(:need_reason), do: "送人进监狱你必须有一个理由才行。"
  defp throw_error_text(:syntax), do: "用法：throw <玩家> [时长] because <理由>"

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end

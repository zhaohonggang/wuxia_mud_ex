defmodule Kantele.Character.VarCommand do
  @moduledoc """
  私有变量命令：`var`（对应 LPC `cmds/arch/var.c`）。

  W3 arch 巫师命令。映射到本端口的 `PlayerMeta.temp` 会话级临时存储
  （与 LPC get_temp/set_temp 一致；本端口 temp 不落盘，详见 PlayerMeta.moduledoc）。

  用法：
  - `var`              列出全部私有变量
  - `var <名称>`        显示单个变量
  - `var <名称> <值>`   设置变量
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, &handle/2)
  end

  defp handle(conn, %{"rest" => rest}) do
    meta = conn.character.meta
    parts = String.split(String.trim(rest), ~r/\s+/, trim: true)

    case parts do
      [] -> list_vars(conn, meta)
      [name] -> show_var(conn, meta, name)
      [name, value] -> set_var(conn, meta, name, value)
      _ -> usage(conn)
    end
  end

  defp handle(conn, _params), do: usage(conn)

  defp list_vars(conn, %PlayerMeta{temp: temp}) do
    text =
      if map_size(temp) == 0 do
        "（无私有变量）\n"
      else
        Enum.map(temp, fn {k, v} -> "#{k} = #{inspect(v)}\n" end)
        |> Enum.join()
      end

    render_text(conn, text)
  end

  defp show_var(conn, %PlayerMeta{temp: temp}, name) do
    text =
      case Map.get(temp, name) do
        nil -> "变量 #{name} 未设置。\n"
        value -> "#{name} = #{inspect(value)}\n"
      end

    render_text(conn, text)
  end

  defp set_var(conn, meta, name, value) do
    new_meta = PlayerMeta.put_temp(meta, name, value)
    conn = %{conn | character: %{conn.character | meta: new_meta}}

    render_text(conn, "已设置 #{name} = #{value}。\n")
  end

  defp usage(conn) do
    render_text(conn, "用法: var [<名称>] [<值>]\n")
  end

  defp render_text(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

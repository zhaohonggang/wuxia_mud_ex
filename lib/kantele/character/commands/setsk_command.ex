defmodule Kantele.Character.SetskCommand do
  @moduledoc """
  设技能命令：`setsk`（对应 LPC `cmds/arch/setsk.c`）。

  W3 arch 巫师命令。设置施法者自身的技能绝对等级（对应 LPC `set_skill`）。

  用法：
  - `setsk <技能> <等级>`   设置技能等级（等级为非负整数）
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, &handle/2)
  end

  defp handle(conn, %{"rest" => rest}) do
    parts = String.split(String.trim(rest), ~r/\s+/, trim: true)

    case parts do
      [skill, level_str] ->
        case Integer.parse(level_str) do
          {level, ""} when level >= 0 -> set_skill(conn, skill, level)
          _ -> usage(conn)
        end

      _ ->
        usage(conn)
    end
  end

  defp handle(conn, _params), do: usage(conn)

  defp set_skill(conn, skill, level) do
    stats = conn.character.meta.stats
    new_stats = Stats.set_skill(stats, skill, level)
    meta = %{conn.character.meta | stats: new_stats}
    conn = %{conn | character: %{conn.character | meta: meta}}

    # 落盘（测试环境无 DB 时 Records.save 安全降级为 :error）
    Records.save(conn.character)

    render_text(conn, "已设置技能 #{skill} = #{level}。\n")
  end

  defp usage(conn) do
    render_text(conn, "用法: setsk <技能> <等级>\n")
  end

  defp render_text(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

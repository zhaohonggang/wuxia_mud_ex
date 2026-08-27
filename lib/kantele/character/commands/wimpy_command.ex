defmodule Kantele.Character.WimpyCommand do
  @moduledoc """
  自动逃跑设置：`wimpy` / `wimpy <百分比>` / `自动逃跑`

  对应 LPC cmds/usr/wimpy.c：设定气血低于百分比时自动触发逃跑。
  阈值范围 0-80，0 表示关闭。存储在 character.meta.wimpy。

  CombatEvent.tick 在每轮战斗结算后检查：当前 qi/max_qi 低于阈值时
  自动发送 room/flee 事件触发逃跑。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  @max_threshold 80

  def run(conn, params) do
    arg = Map.get(params, "arg", "") |> String.trim()

    case arg do
      "" ->
        show_setting(conn)

      _ ->
        set_threshold(conn, arg)
    end
  end

  defp show_setting(conn) do
    wimpy = Map.get(conn.character.meta, :wimpy, 0)

    text =
      case wimpy do
        0 ->
          "你没有设定自动逃跑。\n"

        _ ->
          "你现在的当「气」低于 #{wimpy}% 时就会尝试逃跑。\n"
      end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp set_threshold(conn, arg) do
    case Integer.parse(arg) do
      {value, _rest} when value < 0 or value > @max_threshold ->
        fail(conn, "指令格式：wimpy [<逃跑时「气」的百分比>]（0-#{@max_threshold}）\n")

      {value, _rest} ->
        character = conn.character
        meta = Map.put(character.meta, :wimpy, value)
        character = %{character | meta: meta}

        text =
          case value do
            0 -> "你取消了自动逃跑设定。\n"
            _ -> "Ok. 气低于 #{value}% 时将自动逃跑。\n"
          end

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})

      :error ->
        fail(conn, "指令格式：wimpy [<逃跑时「气」的百分比>]（0-#{@max_threshold}）\n")
    end
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

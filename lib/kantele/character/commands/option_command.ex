defmodule Kantele.Character.OptionCommand do
  @moduledoc """
  界面选项位图：`option` / `option <选项>` / `option <选项> <设定值>`
  （cmds/usr/option.c）

  设定值 0 表示使用系统默认（等价删除该键）。Batch 6 简化：
  选项仅存储展示，具体消费（brief 房间叙述等）留待后续界面重构。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        list_options(conn)

      true ->
        case parse_pair(rest) do
          {:ok, term, nil} ->
            set_option(conn, term, nil)

          {:ok, term, value} ->
            set_option(conn, term, value)

          :error ->
            conn
            |> render(CommandView, "text", %{text: "指令格式：option <选项> <设定值>\n"})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  def run(conn, _params), do: run(conn, %{"rest" => ""})

  defp parse_pair(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [term] -> {:ok, term, nil}
      [term, value] -> {:ok, term, parse_value(value)}
      _ -> :error
    end
  end

  defp parse_value("0"), do: nil

  defp parse_value(int_str) do
    case Integer.parse(int_str) do
      {int, ""} -> int
      _ -> int_str
    end
  end

  defp list_options(conn) do
    options = Map.get(conn.character.meta, :option, %{}) || %{}

    body =
      if map_size(options) == 0 do
        "    無。\n"
      else
        Enum.map_join(options, "", fn {term, v} -> "    #{term} = #{v}\n" end)
      end

    conn
    |> render(CommandView, "text", %{text: "你目前設定的使用者選項：\n#{body}"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp set_option(conn, term, value) do
    character = conn.character
    options = Map.get(character.meta, :option, %{}) || %{}

    options =
      if is_nil(value) do
        Map.delete(options, term)
      else
        Map.put(options, term, value)
      end

    conn
    |> put_character(%{character | meta: %{character.meta | option: options}})
    |> save
    |> render(CommandView, "text", %{text: "Ok.\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(current_character(conn))
    conn
  end

  defp current_character(conn), do: conn.private.update_character || conn.character
end

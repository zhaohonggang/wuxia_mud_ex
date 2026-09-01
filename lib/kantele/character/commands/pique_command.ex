defmodule Kantele.Character.PiqueCommand do
  @moduledoc """
  激怒设置命令：`pique` / `jianu`

  对应 LPC cmds/skill/pique.c：
  设置每次攻击使用的愤怒值。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, params) do
    character = conn.character
    arg = params["arg"] || ""

    case parse_arg(arg) do
      {:ok, :none} ->
        do_set(conn, character, 0)

      {:ok, :max} ->
        max_pts = query_max_craze(character)
        do_set(conn, character, max_pts)

      {:ok, :half} ->
        max_pts = query_max_craze(character)
        do_set(conn, character, div(max_pts, 2))

      {:ok, pts} when is_integer(pts) and pts >= 0 ->
        max_pts = query_max_craze(character)
        if pts > max_pts do
          fail(conn, "你最多只能用#{max_pts}点愤怒值伤敌。\n")
        else
          do_set(conn, character, pts)
        end

      :error ->
        max_pts = query_max_craze(character)
        fail(conn, "指令格式：pique|jianu <使出几点愤怒值伤敌>|max|half|none\n你现在最多能用#{max_pts}点愤怒值伤敌。\n")
    end
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp parse_arg("none"), do: {:ok, :none}
  defp parse_arg("max"), do: {:ok, :max}
  defp parse_arg("half"), do: {:ok, :half}

  defp parse_arg(arg) when is_binary(arg) do
    case Integer.parse(String.trim(arg)) do
      {pts, _} -> {:ok, pts}
      :error -> :error
    end
  end

  defp parse_arg(_), do: :error

  defp do_set(conn, character, 0) do
    character = delete_jianu(character)
    new_conn = put_character(conn, character)

    new_conn
    |> render(CommandView, "text", %{text: "你决定放弃使用愤怒值伤敌。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp do_set(conn, character, pts) do
    character = set_jianu(character, pts)
    new_conn = put_character(conn, character)

    new_conn
    |> render(CommandView, "text", %{text: "你决定用#{pts}点愤怒值伤敌。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp query_max_craze(character) do
    damage = character.meta.damage || %{}
    Map.get(damage, :max_craze, 0)
  end

  defp set_jianu(character, pts) do
    damage = character.meta.damage || %{}
    new_damage = Map.put(damage, :jianu, pts)
    %{character | meta: %{character.meta | damage: new_damage}}
  end

  defp delete_jianu(character) do
    damage = character.meta.damage || %{}
    new_damage = Map.delete(damage, :jianu)
    %{character | meta: %{character.meta | damage: new_damage}}
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

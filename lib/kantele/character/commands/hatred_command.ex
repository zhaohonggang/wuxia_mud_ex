defmodule Kantele.Character.HatredCommand do
  @moduledoc """
  仇人列表命令：`hatred [玩家|门派]`

  对应 LPC cmds/usr/hatred.c；列出本门派在江湖上的仇敌（按仇恨度降序，取前 30）。
  本实现以玩家所属门派名查 `Kantele.League` 的领域仇人表；巫师指定门派/玩家分支
  依赖 P4 管理员框架，未迁移。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.League

  def run(conn, %{"arg" => _arg}) do
    character = conn.character
    family = family_name(character.meta)

    if is_nil(family) do
      render_msg(conn, "你现在还没有加入一个门派呢。\n")
    else
      hatred = League.query_league_hatred(family)

      cond do
        map_size(hatred) == 0 ->
          render_msg(conn, "#{family}现在没有什么仇人。\n")

        true ->
          rows =
            hatred
            |> Enum.sort_by(fn {_id, [_n, lvl]} -> -lvl end)
            |> Enum.take(30)
            |> Enum.with_index(1)
            |> Enum.map_join("", fn {{id, [name, lvl]}, i} ->
              "#{String.pad_leading("#{i}", 3)}. #{name}(#{id})  仇恨度 #{lvl}\n"
            end)

          total = map_size(hatred)

          render_msg(
            conn,
            "目前#{family}在江湖上的仇敌都有\n--------------------------------\n" <>
              rows <>
              "--------------------------------\n目前一共是#{total}人。\n"
          )
      end
    end
  end

  def run(conn, %{}) do
    run(conn, %{"arg" => ""})
  end

  def run_bare(conn, %{}) do
    run(conn, %{"arg" => ""})
  end

  defp family_name(meta) do
    case meta.family do
      %{name: name} when is_binary(name) and name != "" -> name
      _ -> nil
    end
  end

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

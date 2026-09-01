defmodule Kantele.Character.BrothersCommand do
  @moduledoc """
  结义命令：`brothers` | `brothers out <name>`

  对应 LPC cmds/usr/brothers.c
  查看结拜兄弟列表，或解除结义关系。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    cond do
      rest == "" ->
        list_brothers(conn)

      String.starts_with?(rest, "out ") ->
        name = String.trim(String.slice(rest, 4..-1))
        break_oath(conn, name)

      true ->
        conn
        |> render(CommandView, "text", %{text: "指令格式：brothers | brothers out <name>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def run(conn, %{}) do
    list_brothers(conn)
  end

  defp list_brothers(conn) do
    character = conn.character
    brothers = PlayerMeta.brothers(character.meta)

    if brothers == [] do
      conn
      |> render(CommandView, "text", %{text: "你现在还没有结义的兄弟们。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      brother_list =
        brothers
        |> Enum.map(fn %{id: id, name: name} -> "#{name}(#{id})" end)
        |> Enum.join("、")

      conn
      |> render(CommandView, "text", %{text: "你现在结义的兄弟有：#{brother_list}\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp break_oath(conn, name) do
    character = conn.character

    case Enum.find(PlayerMeta.brothers(character.meta), &(&1.name == name)) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你现在没有这个结拜兄弟啊。\n"})
        |> prompt(CommandView, "prompt", %{})

      target ->
        if PlayerMeta.get_temp(character.meta, "pending/brother_out") == name do
          confirmed_break(conn, target)
        else
          character = PlayerMeta.put_temp(character.meta, "pending/brother_out", name)
          conn = put_character(conn, %{conn.character | meta: character})
          save(conn)

          conn
          |> render(CommandView, "text", %{
            text: "你确定要和这位朋友(#{name})割袍断义吗？\n" <>
                    "如果你确定，请再输入一次这条命令。\n"
          })
          |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp confirmed_break(conn, target) do
    character = conn.character
    name = target.name

    remaining = Enum.reject(PlayerMeta.brothers(character.meta), &(&1.id == target.id))

    meta =
      character.meta
      |> PlayerMeta.put_brothers(remaining)
      |> PlayerMeta.delete_temp("pending/brother_out")

    new_conn = put_character(conn, %{character | meta: meta})
    save(new_conn)

    # TODO: 通知对方并同步移除对方名单（需跨角色更新，后续批处理）
    # LPC 用 UPDATE_D 清除双方 brothers:<id> 关联；此处先只改己方名单。

    new_conn
    |> render(CommandView, "text", %{text: "你和#{name}断绝了关系。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
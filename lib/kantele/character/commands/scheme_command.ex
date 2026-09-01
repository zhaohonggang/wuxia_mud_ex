defmodule Kantele.Character.SchemeCommand do
  @moduledoc """
  计划命令：`scheme [<计划文本> | edit <计划文本> | clear | show]`

  对应 LPC cmds/usr/scheme.c。制订/查看/清除个人计划（落盘 metadata.schedule）：
  - `scheme`                 查看当前计划
  - `scheme <计划文本>`       制订一份新计划（多步以换行分隔）
  - `scheme edit <计划文本>`  同上（别名）
  - `scheme clear`           清除当前计划
  - `scheme show [玩家]`     查看计划（指定玩家为巫师功能，未迁移）

  注：LPC 的 `scheme start`（REPEAT/LOOP 计划自动执行器）依赖食水 vitals、
  learned_points 消耗与 busy 状态的深度自动化，当前代码库尚无对应子系统，
  本期不迁移执行器，仅落实计划数据的制订/查看/清除。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"arg" => arg}) do
    arg = String.trim(arg || "")

    case arg do
      "" ->
        show(conn)

      "clear" ->
        clear(conn)

      "show" ->
        show(conn)

      "edit" ->
        render_msg(conn, "请用 scheme <计划文本> 直接制订你的计划。\n")

      "start" ->
        render_msg(conn, "计划自动执行功能暂未开放，你可以用 scheme <计划文本> 制订计划。\n")

      _ ->
        text =
          case String.split(arg, ~r/\s+/, parts: 2) do
            ["edit", rest] when rest != "" -> String.trim(rest)
            _ -> arg
          end

        set(conn, text)
    end
  end

  def run(conn, %{}) do
    show(conn)
  end

  def run_bare(conn, %{}) do
    run(conn, %{})
  end

  defp show(conn) do
    case conn.character.meta.schedule do
      nil ->
        render_msg(conn, "你目前并没有制订任何计划。\n")

      schedule ->
        render_msg(conn, "你目前制订的计划如下：\n#{schedule}\n")
    end
  end

  defp set(conn, text) when is_binary(text) and text != "" do
    if String.length(text) > 400 do
      render_msg(conn, "你这份计划太长了，请重新设置一个短一些的。\n")
    else
      meta = %{conn.character.meta | schedule: text}
      new_conn = put_character(conn, %{conn.character | meta: meta})

      new_conn
      |> render_msg("你设置了一份新的计划。\n")
      |> save()
    end
  end

  defp set(conn, _), do: render_msg(conn, "你没有输入任何新的计划。\n")

  defp clear(conn) do
    meta = %{conn.character.meta | schedule: nil}
    new_conn = put_character(conn, %{conn.character | meta: meta})

    new_conn
    |> render_msg("Ok.\n")
    |> save()
  end

  defp render_msg(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end

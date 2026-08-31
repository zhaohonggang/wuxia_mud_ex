defmodule Kantele.Character.NoteCommand do
  @moduledoc """
  便笺/行编辑器命令 `note`（对应 `feature/edit.c` 的宿主接线）

  采用 `Kantele.Editor.Line` 纯状态机做逐行累积；由于本框架每条输入都被当作
  命令解析（无 LPC `input_to` 的裸行捕获），实际游戏中逐行编辑以"每行以
  `note ` 为前缀"的方式驱动：

  - `note`           查看当前正在编辑的便笺（或开场提示，无便笺时新开一段）
  - `note <行>`       追加一行正文
  - `note .`          结束并输出整篇便笺（清空会话）
  - `note ~q`         取消编辑（弃稿）
  - `note ~e`         内建 vi 编辑器未移植（保持编辑状态）

  注：由于本框架方向别名 `n`/`s` 等按前缀匹配（`note` 单字会被 `north` 的
  `n` 吞并，`sleep` 会被 `south` 吞并），`note` 必须跟一个正文参数才能被本
  命令捕获；因此上面所有操作都以 `note `<正文/`.`/`~q`> 形式书写。

  会话状态临时存于 `character.meta.temp["note_session"]`，不落盘；仅结束时 save。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Editor.Line

  @session "note_session"

  def run(conn, %{"rest" => rest}) do
    rest = rest || ""
    character = conn.character
    state = PlayerMeta.get_temp(character.meta, @session, %{lines: []})
    {state, result} = Line.accumulate(state, rest)

    case result do
      {:done, text} ->
        finish(conn, character.meta, text)

      :continue ->
        continue(conn, character.meta, state)

      :cancel ->
        cancel(conn, character.meta)

      :use_vi ->
        conn
        |> render(CommandView, "text", %{
          text: "内建 vi 编辑器尚未提供，请用 `note ~q` 取消或继续逐行输入。\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp finish(conn, meta, text) do
    meta = PlayerMeta.put_temp(meta, @session, nil)

    conn
    |> put_character(put_meta(conn.character, meta))
    |> render(CommandView, "text", %{text: "便笺完成：\n---\n#{text}\n---\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp continue(conn, meta, state) do
    meta = PlayerMeta.put_temp(meta, @session, state)
    body = Enum.join(state.lines, "\n")

    text =
      if body == "" do
        Line.instructions()
      else
        "当前便笺：\n#{body}\n（继续输入，`.` 结束，`~q` 取消）\n"
      end

    conn
    |> put_character(put_meta(conn.character, meta))
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp cancel(conn, meta) do
    meta = PlayerMeta.put_temp(meta, @session, nil)

    conn
    |> put_character(put_meta(conn.character, meta))
    |> render(CommandView, "text", %{text: "取消编辑，便笺已丢弃。\n"})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  defp put_meta(character, meta), do: %{character | meta: meta}

  defp save(conn) do
    Kantele.Character.Records.save(conn.private.update_character || conn.character)
    conn
  end
end

defmodule Kantele.Character.SaveCommand do
  @moduledoc """
  手动存档：`save`（cmds/usr/save.c；实时已自存，此命令仅给安心感）

  Batch 6：直接调用 `Records.save/1` 落盘并反馈结果。为降低负载，
  LPC 限制 30 秒内的重复存档，Kantele 侧实时自存已覆盖，故不再限流。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, _params) do
    conn =
      case Records.save(conn.character) do
        :ok ->
          render(conn, CommandView, "text", %{text: "档案储存完毕。\n"})

        :error ->
          render(conn, CommandView, "text", %{text: "储存失败。\n"})
      end

    prompt(conn, CommandView, "prompt", %{})
  end
end

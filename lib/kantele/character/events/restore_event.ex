defmodule Kantele.Character.RestoreEvent do
  @moduledoc """
  角色自身从数据库存档重载运行态。

  由 `restore` 命令向目标进程发送 `character/restore` 事件触发；目标进程在此
  自行 `Records.load` 当前角色名对应的存档并 `apply_to_character` 回写，不依赖
  外部进程改写其状态（与 `character/teleport` 同款「外部发起、自身执行」模式）。

  对应 LPC `restore` 把玩家数据从存档恢复的核心语义。
  """
  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def run(conn, %{data: _data}) do
    case Records.load(conn.character.name) do
      {:ok, metadata, wiz_level} ->
        conn = put_character(conn, Records.apply_to_character(conn.character, {:ok, metadata}, wiz_level))
        reply(conn, "已从数据库存档恢复你的角色状态。\n")

      :error ->
        reply(conn, "没有找到你的存档，无法恢复。\n")
    end
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end

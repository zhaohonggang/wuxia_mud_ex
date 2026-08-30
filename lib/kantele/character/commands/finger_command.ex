defmodule Kantele.Character.FingerCommand do
  @moduledoc """
  指尖命令：`finger`, `查找`

  对应 LPC cmds/usr/finger.c
  查看玩家信息。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def list(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "在线玩家列表暂未开放。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{"name" => name}) do
    conn
    |> render(CommandView, "text", %{text: "没有找到 #{name}。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, _params) do
    character = conn.character

    info = """
    【 角色 】 #{character.name}
    【 ID 】 #{character.id}
    【 状态 】 暂未开放
    """

    conn
    |> render(CommandView, "text", %{text: info})
    |> prompt(CommandView, "prompt", %{})
  end
end

defmodule Kantele.Character.FingerCommand do
  @moduledoc """
  查找命令：`finger [使用者姓名]`（cmds/usr/finger.c 多玩家资料版）

  无参数时列出全体在线玩家（同 who）；带名字时查找该玩家并展示其连线资料。
  简化：不做 LPC 的 jing 消耗与 10 秒扫描冷却。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.FingerView
  alias Kantele.Character.Presence

  def run(conn, %{"name" => name}) do
    case find_player(name) do
      nil ->
        conn
        |> assign(:name, name)
        |> render(FingerView, "not-found")

      character ->
        conn
        |> assign(:character, character)
        |> render(FingerView, "player")
    end
  end

  def list(conn, _params) do
    conn
    |> assign(:characters, Presence.characters())
    |> render(FingerView, "list")
  end

  defp find_player(name) do
    key = name |> String.downcase() |> String.trim()

    Enum.find(Presence.characters(), fn character ->
      cname = to_string(character.name) |> String.downcase()
      cname == key or String.starts_with?(cname, "#{key} ")
    end)
  end
end

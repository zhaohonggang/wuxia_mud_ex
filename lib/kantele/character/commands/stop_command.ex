defmodule Kantele.Character.StopCommand do
  @moduledoc """
  停止命令：`stop <野兽>`（LPC `cmds/std/stop.c`）。

  让帮自己咬人的野兽停手：参数 → present → 必须是自己的 → 野兽不忙 →
  `message_vision` → `remove_all_enemy(1)`（清 `BeastState.enemies`）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.BeastTaming, as: Taming

  def run(conn, params) do
    arg =
      params
      |> Map.get("target", "")
      |> to_string()
      |> String.trim()

    cond do
      arg == "" ->
        Taming.reject(conn, "你要让什么野兽停止咬人？\n")

      true ->
        case Taming.find(conn, arg) do
          nil -> Taming.reject(conn, "这里没有这个野兽吧？\n")
          npc -> adjudicate(conn, npc)
        end
    end
  end

  defp adjudicate(conn, npc) do
    me = conn.character
    name = to_string(npc.name)

    cond do
      not Taming.owned_by?(npc, me) ->
        Taming.reject(conn, "你不是它的主人，它根本不理你！\n")

      Taming.busy?(npc) ->
        Taming.reject(conn, "#{name}正在忙乎，没空理你！\n")

      true ->
        text =
          "只见#{me.name}冲着#{name}口中一声呼哨，#{name}向后一窜，不咬了！\n"

        Taming.halt(npc)
        Taming.emit(conn, text)
    end
  end
end

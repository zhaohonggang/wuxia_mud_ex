defmodule Kantele.Character.ReleaseCommand do
  @moduledoc """
  放生命令：`release`（LPC `cmds/std/release.c`，源文件名是 `fang.c`）。

  遍历 `all_inventory(environment(me))`，把所有 `query_temp("owner") == me`
  的野兽逐条播报并删掉 owner / owner_id / owner_name；一头都没有则播报
  「想放生，可是啥可放的」。

  与 LPC 一致：`attitude` / `ridable` 是 `set()` 不是 temp，放生后不清除；
  也不动玩家侧的 `comedby`（`stay` 会因找不到对象而提示「已经没有野兽跟着你了」）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.BeastTaming, as: Taming

  def run(conn, _params) do
    me = conn.character

    case Taming.release_owned(conn, me) do
      [] ->
        Taming.emit(conn, "#{me.name}想放生，可是没啥可放的。\n")

      released ->
        text =
          Enum.map_join(released, "", fn npc ->
            "#{me.name}很慈悲地把#{npc.name}放离，任其回归自然了。\n"
          end)

        Taming.emit(conn, text)
    end
  end
end

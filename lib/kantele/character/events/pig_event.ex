defmodule Kantele.Character.PigEvent do
  @moduledoc """
  拱猪座位同步（动作 handler 判定 → 角色进程落地）。

  ## 为什么需要它

  LPC `pigroom.c` 里桌长散桌时会**直接改别人的 temp**：

      pl[seat[i]]->delete_temp("pigging_seat");

  本移植里 `meta` 只有角色自己的进程能安全修改（`Kantele.Character.Records`
  也只在该进程里落盘），因此 `RoomActions.City.PigRoom` 对**同桌其他人**的
  座位变更只发事件 `pig/seat`，由各自的角色进程执行 `set_temp` / `delete_temp`。
  行动者自己的座位则在同一 handler 里直接改（避免一次多余的往返）。

  对应关系：

  - `event("pig/seat", %{seat: "north"})` → `set_temp("pigging_seat", "north")`
  - `event("pig/seat", %{seat: nil})`     → `delete_temp("pigging_seat")`

  该 temp 是**会话级**运行态（不落盘），`look table` 与 `valid_leave`
  （`me->query_temp('pigging_seat')`）都读它。
  """

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta

  @doc "topic: pig/seat -> seat/2"
  def seat(conn, %{data: %{seat: seat}}) do
    character = conn.private.update_character || conn.character

    meta =
      case seat do
        nil -> PlayerMeta.delete_temp(character.meta, "pigging_seat")
        s when is_binary(s) and s != "" -> PlayerMeta.put_temp(character.meta, "pigging_seat", s)
        _ -> PlayerMeta.delete_temp(character.meta, "pigging_seat")
      end

    put_character(conn, %{character | meta: meta})
  end
end

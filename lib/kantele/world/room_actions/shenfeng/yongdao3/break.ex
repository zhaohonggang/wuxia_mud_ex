defmodule Kantele.World.RoomActions.Shenfeng.Yongdao3.Break do
  @moduledoc """
  `d/shenfeng/yongdao3.c` 的 `do_break`（LPC 目标词 `gate`）。

  - 参数非 `gate` → 提示「你要毁掉什么？」
  - 已开（north 出口存在）→ 提示「石门已经被劈开了，还劈什么？」
  - 空手：
      * 武力 < 200 → 扣 qi 300 + 内力清零 + 昏厥（被反弹力震飞）。
      * 武力 ≥ 200 → 内力清零（闷响、纹丝未动，不昏厥）。
  - 持武器：
      * 武力 < 200 或武器不是「黄金斧」→ 武器脱手飞出（虎口一震），不开门。
      * 否则 → 双向开门：self north→shenfeng:yongdao4、neighbor yongdao4
        south→self（**无自动关门**）。
  - LPC `base_name(ob) != HUANGJINFU` 用武器文件全路径判定；本引擎装备快照
    （`combat.equipped[:weapon]`）只含 `name`/`skill_type`/`damage`/`prop`/`flag`，
    不含文件路径，故改用武器显示名「黄金斧」等价判定（见 `Break.weapon_name/1`）。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.DynamicExit
  alias Kantele.World.RoomActions.Helpers

  @huangjinfu "黄金斧"
  @neighbor "shenfeng:yongdao4"
  @self "shenfeng:yongdao3"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    if String.trim(arg) != "gate" do
      Helpers.render_to_player(conn, "你要毁掉什么？\n")
    else
      if Break.open?(room_id, "north") do
        Helpers.render_to_player(conn, "石门已经被劈开了，还劈什么？\n")
      else
        char = Break.current(conn)
        weapon = Break.wielded_weapon(char)

        if is_nil(weapon) do
          break_empty_hand(conn, room_id, char)
        else
          name = Break.weapon_name(char)
          conn = Break.broadcast(conn, room_id, "\n$N高高举起手中的#{name}，朝石门猛劈而去！\n")

          if Break.force_level(char) < 200 or name != @huangjinfu do
            conn
            |> Break.broadcast(room_id, "结果只听「铛」的一声，$N虎口一震，#{name}禁不住脱手飞出。\n\n")
            |> Break.unequip_weapon()
          else
            open_gate(conn, room_id)
          end
        end
      end
    end
  end

  defp break_empty_hand(conn, room_id, char) do
    conn = Break.broadcast(conn, room_id, "\n$N气沉丹田扎稳马步，大吼一声，双拳猛的击向石门！\n")

    if Break.force_level(char) < 200 do
      conn
      |> Break.broadcast(room_id, "结果只听$N一声闷哼，被石门的反弹力震得飞了出去。\n\n")
      |> Break.wound_qi(300)
      |> Break.pass_out()
    else
      conn
      |> Break.broadcast(room_id, "结果只听轰的一声闷响，那石门却是纹丝未动。\n\n")
      |> Break.set_neili(0)
    end
  end

  defp open_gate(conn, room_id) do
    conn = Break.broadcast(conn, room_id, "只听「轰」的一声巨响，石门已被$N劈得粉碎，露出一个洞口。\n\n")

    conn = DynamicExit.open(conn, room_id, "north", @neighbor, "")

    Room.set_exit(@neighbor, "south", @self)
    Room.tell_room(%Room{id: @neighbor}, "\n只听外面「轰」的一声巨响，石门被人劈开了。\n")

    conn
  end
end

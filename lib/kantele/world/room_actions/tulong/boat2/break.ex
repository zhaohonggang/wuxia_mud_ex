defmodule Kantele.World.RoomActions.Tulong.Boat2.Break do
  @moduledoc """
  `d/tulong/tulong/boat2.c` 的 `do_break`（`add_action("do_break", "break")`，
  目标词 `boat`/`船`）—— 砸断巨鲸帮座船桅杆（P5-6 门/容器收尾批：最后 2 处
  `do_break` 之二）。

  LPC 原文：

      int do_break(string arg)
      {
              object me=this_player(),inv;
              if (arg!="boat" && arg!="船") return notify_fail("你要打碎什么？\\n");
              inv=present("stone",me);
              if (query("dao")) return notify_fail("船上的桅杆早就倒了，还砸什么？\\n");
              if (!objectp(inv)) return notify_fail("你准备拿什么砸船呀？\\n");
              else
              {
              message_vision("$N举起手中"+inv->query("name")+"，向船上的桅杆砸去。\\n",me);
              remove_call_out("do_dao");
              call_out("do_dao",3,me);
              return 1;
              }
      }

      int do_dao(object me)
      {
              message_vision( WHT "\\n只听得喀喇、喀喇之声不绝，耸立的船桅一根根倒将下来。\\n砰嘭之声不绝，顷刻之间，众桅杆或倒或斜，无一得免。\\n" NOR,me);
              set("dao",1);
              set("long","这些大船，想是巨鲸帮、海沙派一干人的座船。只是桅杆都被砸断了。\\n");
              me->set_temp("dao",1);
              return 1;
      }

  ## 移植要点

  - 目标词 `boat`/`船`（中文也认），否则 `notify_fail("你要打碎什么？\\n")`。
  - 判定顺序照抄 LPC：**先 `query("dao")`（已砸过 → 「早就倒了」）再查石头**。
    `present("stone", me)` 查的是**背包**：石头（`tulong:stone`）在
    `room_items "boat2"` 地上，玩家要先 `get stone` 才能砸——这正是 LPC 的两步设计。
  - `inv->query("name")` 拼进 `message_vision` 文案：用
    `Helpers.carried_item/2` 取背包里石头的定义名（「大石头」）。
  - `call_out("do_dao", 3)` → `:timer.apply_after` + `trap/effect` 事件（同
    `Jueqing.Duanchang`）：延时进程无 `conn`，按角色 pid 下发 `:text` 与
    `:set_temp`；房间侧 `set("dao",1)` 与 `set("long", ...)` 在定时器回调里直接
    写房间 state（`Room.put_state_by_id/3`，无需 conn）。
  - `set("long", ...)` → `Room.put_state_by_id(room_id, "long", text)`；`look` 经
    `Room.long_description/1` 优先读该键（本批次新增的运行期房述覆盖）。
  - `break` 非全局命令，遮蔽不损失既有功能。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kalevala.Event

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @args ["boat", "船"]
  @stone "stone"
  @state_key "dao"
  @delay_ms 3_000

  @raised "$N举起手中%{item}，向船上的桅杆砸去。\n"
  @masts_fall "\n只听得喀喇、喀喇之声不绝，耸立的船桅一根根倒将下来。\n砰嘭之声不绝，顷刻之间，众桅杆或倒或斜，无一得免。\n"
  @new_long "这些大船，想是巨鲸帮、海沙派一干人的座船。只是桅杆都被砸断了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      arg not in @args ->
        Helpers.render_to_player(conn, "你要打碎什么？\n")

      # LPC 先判 query("dao")（已砸过）
      Room.get_state_by_id(room_id, @state_key) ->
        Helpers.render_to_player(conn, "船上的桅杆早就倒了，还砸什么？\n")

      true ->
        raise_stone(conn, room_id)
    end
  end

  defp raise_stone(conn, room_id) do
    character = conn.private.update_character || conn.character

    case Helpers.carried_item(character, @stone) do
      nil ->
        Helpers.render_to_player(conn, "你准备拿什么砸船呀？\n")

      item ->
        conn
        |> Helpers.broadcast_vision(room_id, String.replace(@raised, "%{item}", item.name))
        |> schedule_dao(room_id)
    end
  end

  defp schedule_dao(conn, room_id) do
    :timer.apply_after(@delay_ms, __MODULE__, :fire_dao, [room_id, pid_of(conn)])
    conn
  end

  @doc "`call_out(\"do_dao\", 3)` 的独立进程回调：房间侧置 `dao` + 改 `long`，玩家侧置 temp。"
  def fire_dao(room_id, pid) when is_binary(room_id) do
    Room.put_state_by_id(room_id, @state_key, 1)
    Room.put_state_by_id(room_id, "long", @new_long)

    if is_pid(pid) do
      effects = [
        {:text, @masts_fall},
        {:set_temp, "dao", 1}
      ]

      send(pid, %Event{from_pid: self(), topic: "trap/effect", data: %{effects: effects}})
    end

    :ok
  end

  defp pid_of(conn) do
    character = conn.private.update_character || conn.character
    if is_map(character), do: character.pid
  end

end

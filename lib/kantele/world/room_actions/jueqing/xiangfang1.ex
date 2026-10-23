defmodule Kantele.World.RoomActions.Jueqing.Xiangfang1 do
  @moduledoc """
  `d/jueqing/xiangfang1.c` 的 `do_turn`（`add_action("do_turn", ({"turn","zhuan"}))`）
  与 `do_jump`（`add_action("do_jump", ({"tiao","jump"}))`）。

  ## do_turn "pen"
  - arg 须为 `pen`，否则 `notify_fail("你要做什么？\\n")`。
  - busy/fighting 守卫（LPC 文案）。
  - 机关状态存房间 state `marks/转`（LPC `ob->set_temp/delete_temp("marks/转")` 写在
    房间单例上，故用 `Room.put_state_by_id/delete_state_by_id`）。
  - 已开 → 关闭：广播「洞口被封住」+ 删 `marks/转`。
  - 未开 → 打开：广播「露出洞口(dong)」+ 置 `marks/转`。
  - LPC 还有 `set("long", ...)` 改写房间描述：引擎运行时无等价能力，已由上方广播文案
    覆盖玩家可见效果，仅维护 `marks/转` 状态位（UCL 静态 description 已是「露洞」版，
    与 LPC `create()` 的「未露洞」版有出入，属呈现层差异，不影响机关逻辑）。

  ## do_jump "dong"/"hole"
  - arg 须为 `dong`/`hole`，否则 `notify_fail("你要做什么？\\n")`。
  - busy/fighting 守卫。
  - 未开机关（`marks/转` 未置）→ `notify_fail("你乱跳什么？")`。
  - 已开：向本房广播（排除行动者）「$N 纵身一跃，跳进床头的洞口…」+ 行动者私有文案
    「你纵身一跃，进入洞中…」+ `call_out("tell_player", random(4)+3)` 延时落到
    `eyutan2`。
  - `tell_player` 延时：给行动者私有文案「思念未定，扑通一声…」+ 向 `eyutan1` 广播
    （排除行动者）「<name> 从上面跳下，坠入潭中。」+ `me->move(eyutan2)`。
    延时回调无 conn，复用 `trap/effect` 事件按 pid 下发 `:text`/`:force_move`，
    另用 `Room.tell_room` 向 `eyutan1`（行动者当时已不在的那间）播报——该广播需直接
    嵌入行动者名字（LPC `me->name()`），因为 `Room.tell_room` 不做 `{npc}` 归一。

  注：LPC `remove_call_out("tell_player")` 在每次跳转前取消上一轮定时器；本模块与同批的
  `duanchang`/`underya` 保持一致**不取消**（避免把 timer ref 存进持久化的 meta.temp
  引发序列化问题）——重复跳转 3~7 秒内会排多个定时器，均为落到 eyutan2，结果幂等，影响极小。
  """
  use Kantele.World.RoomAction

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @marks_key "marks/转"
  @from_room "jueqing:eyutan1"
  @to_room "jueqing:eyutan2"

  @impl true
  def run(conn, %{verb: verb, trailing: arg, room_id: room_id}) do
    case verb do
      v when v in ["turn", "zhuan"] -> do_turn(conn, room_id, String.trim(arg))
      v when v in ["jump", "tiao"] -> do_jump(conn, room_id, String.trim(arg))
      _ -> conn
    end
  end

  # ---------- do_turn ----------
  defp do_turn(conn, room_id, arg) do
    if arg != "pen" do
      Helpers.render_to_player(conn, "你要做什么？\n")
    else
      case guard(conn) do
        {:halt, c} -> c
        :ok -> toggle(conn, room_id)
      end
    end
  end

  defp toggle(conn, room_id) do
    if Room.get_state_by_id(room_id, @marks_key) do
      # 关闭机关
      Room.delete_state_by_id(room_id, @marks_key)

      Helpers.broadcast_vision(
        conn,
        room_id,
        "\n$N轻轻地转动花盆，一阵巨响从床头传出，原来露出的洞口已被完全封住，已经也看不出来这下面隐藏的暗道。\n"
      )
    else
      # 打开机关
      Room.put_state_by_id(room_id, @marks_key, 1)

      Helpers.broadcast_vision(
        conn,
        room_id,
        "\n$N轻轻地转动花盆，一阵巨响从床头传出，定睛一看，只见床头处露出一个洞口(dong)来，原来这里竟隐藏着暗道。\n"
      )
    end
  end

  # ---------- do_jump ----------
  defp do_jump(conn, room_id, arg) do
    if arg not in ["dong", "hole"] do
      Helpers.render_to_player(conn, "你要做什么？\n")
    else
      case guard(conn) do
        {:halt, c} -> c
        :ok -> leap_or_refuse(conn, room_id)
      end
    end
  end

  defp leap_or_refuse(conn, room_id) do
    if Room.get_state_by_id(room_id, @marks_key) do
      leap(conn, room_id)
    else
      Helpers.render_to_player(conn, "你乱跳什么？")
    end
  end

  defp leap(conn, room_id) do
    name = current(conn).name

    conn
    |> Helpers.broadcast_vision(
      room_id,
      "{npc}纵身一跃，跳进床头的洞口…\n",
      exclude_actor: true
    )
    |> Helpers.render_to_player(
      "\n你纵身一跃，进入洞中，耳边寒风飕飕，此洞深不见底，但觉\n足底空虚，竟似直堕了数十丈尚未著地…\n"
    )
    |> schedule_fall(name)
  end

  defp schedule_fall(conn, name) do
    pid = current(conn).pid

    :timer.apply_after(random_delay(3000, 4000), __MODULE__, :fire_effect, [pid, name, @from_room, @to_room])
    conn
  end

  # `:timer.apply_after` 的独立进程回调：向 eyutan1 广播（直接嵌入行动者名字），
  # 并按角色 pid 下发 trap 副作用（私有文案 + 落到 eyutan2）。
  def fire_effect(pid, name, from_room_id, to_room_id) when is_pid(pid) do
    Room.tell_room(%Room{id: from_room_id}, name <> "从上面跳下，坠入潭中。\n")

    send(pid, %Event{
      from_pid: self(),
      topic: "trap/effect",
      data: %{
        effects: [
          {:text, "思念未定，扑通一声，你已摔入水中，往下急沉。\n"},
          {:force_move, to_room_id}
        ]
      }
    })

    :ok
  end

  # ---------- 共享守卫 / 工具 ----------
  defp guard(conn) do
    c = current(conn)

    cond do
      Combat.busy?(c.meta.combat) ->
        {:halt, Helpers.render_to_player(conn, "你现在正忙着呢！\n")}

      Combat.fighting?(c.meta.combat) ->
        {:halt, Helpers.render_to_player(conn, "你还是先把你面前这个家伙解决了再说。\n")}

      true ->
        :ok
    end
  end

  defp random_delay(base, span), do: :rand.uniform(span) + base

  defp current(%{private: %{update_character: c}} = conn) when not is_nil(c), do: c
  defp current(%{character: c}), do: c
end

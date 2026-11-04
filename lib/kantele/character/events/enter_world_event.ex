defmodule Kantele.Character.EnterWorldEvent do
  @moduledoc """
  无间道 `entering_world` 动画的玩家侧处理器。

  由 `Kantele.World.RoomActions.Death.WujiandaoEnter` 通过
  `Process.send_after(pid, %Event{topic: "character/entering_world_step", ...})`
  发送，经玩家 foreman 路由到本模块。各步在玩家进程内执行，可安全修改
  角色 meta、调用 `Reborn.trigger` 和 `Teleport.teleport`。

  对应 LPC `entering_world(object me, int n)` 的 call_out 链。
  """

  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.Reborn
  alias Kantele.Character.Teleport
  alias Kantele.World.RoomActions.Helpers

  @enter_msgs [
    "\n你只觉得眼前一花，突然什么也听不见，什么也看不见......\n\n",
    "只觉得身体不断的下坠......\n\n",
    "坠向无尽的黑暗......\n\n",
    "忽然仿佛一只大手托了你一下......\n\n",
    "冥冥中隐约传来阵阵叮叮当当碰撞声......\n\n",
    "你睁眼一看，发现自己已置身于一个喧嚣而似乎并不陌生的世界......\n\n",
  ]

  @impl true
  def entering_world_step(conn, %{data: %{step: step, room_id: room_id, character_id: _character_id}}) do
    character = conn.character

    # 向玩家私发当前段文案（LPC tell_object(me, enter_msg[n])）
    conn = Helpers.render_to_player(conn, Enum.at(@enter_msgs, step))

    cond do
      step == length(@enter_msgs) - 1 ->
        # 最后一段：执行转世
        complete_rebirth(conn, character, room_id)

      true ->
        # 继续下一段（间隔 3 秒，LPC call_out("entering_world", 3, me, n+1)）
        Process.send_after(
          character.pid,
          %Event{
            from_pid: self(),
            topic: "character/entering_world_step",
            data: %{step: step + 1, room_id: room_id, character_id: character.id}
          },
          3000
        )
        conn
    end
  end

  defp complete_rebirth(conn, character, _room_id) do
    # 清除 entering_world 临时标记（LPC delete_temp("entering_world")）
    character = delete_temp(character, "entering_world")

    # 执行转世（LPC UPDATE_D->zhuan_player(me)）
    case Reborn.trigger(character) do
      {:ok, new_character} ->
        conn = put_character(conn, new_character)

        # 传送至城外武庙（LPC me->move("/d/city/wumiao")）
        conn = Teleport.teleport(conn, "city:wumiao")
        character = conn.character

        # 广播出现文案（LPC tell_room(environment(me), me->name()+"突然出现在眼前。\n", ({me}))）
        conn =
          Helpers.broadcast_vision(
            conn,
            "city:wumiao",
            "#{character.name}突然出现在眼前。\n"
          )

        conn

      {:error, msg} ->
        Helpers.render_to_player(conn, msg)
        conn
    end
  end

  defp delete_temp(%{meta: meta} = character, key) do
    temp = Map.delete(meta.temp || %{}, key)
    %{character | meta: %{meta | temp: temp}}
  end
end

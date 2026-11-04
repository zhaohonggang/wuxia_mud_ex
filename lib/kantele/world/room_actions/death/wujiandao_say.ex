defmodule Kantele.World.RoomActions.Death.WujiandaoSay do
  @moduledoc """
  `d/death/liudaolunhui/wujiandao.c` 的 `do_say`（`add_action("do_say", "say")`）。

  玩家在无间道诵读特定诗句，若 `poem_said` 尚未置位：
  1. 房间广播：$N猛然高声喝道“潜能无限，精意神通，身居祸福，自我主宰！”
  2. 授予玩家「无间闪电」武器
  3. 房间广播：电闪雷鸣，无间闪电穿进$N怀中
  4. 置位 `poem_said=1`（房间 state）

  若 `poem_said` 已置位，再次诵读则只给玩家私发文案。

  非诗句输入返回 `:not_handled`，交回全局 say 命令。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @poem "潜能无限，精意神通，身居祸福，自我主宰！"
  @wujian_item_id "death:wujian"
  @poem_said_key "poem_said"

  @repeat_poem_text "\n你对着黑暗一声猛喝，声音在司内回荡了好一阵才消逝。\n"

  @enter_vision_part1 "\n只听{npc}猛然高声喝道：“潜能无限，精意神通，身居祸福，自我主宰！”\n"
  @enter_vision_part2 "$N话音刚落，地面突然「轰隆隆」晃动了几下。眼前出现了一个镜子。\n\n"
  @enter_vision_part3 "突然间电闪雷鸣，宇宙无敌之剑无间闪电伴随着道道闪电穿进{npc}的怀中！\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    trimmed = String.trim(arg)

    cond do
      trimmed == "" ->
        :not_handled

      trimmed != @poem ->
        :not_handled

      poem_said?(room_id) ->
        Helpers.render_to_player(conn, @repeat_poem_text)

      true ->
        conn
        |> broadcast_enter_vision(room_id)
        |> give_wujian()
        |> broadcast_flash_vision(room_id)
        |> put_poem_said(room_id)
    end
  end

  defp poem_said?(room_id) do
    case Room.get_state_by_id(room_id, @poem_said_key) do
      1 -> true
      _ -> false
    end
  end

  defp put_poem_said(conn, room_id) do
    Room.put_state_by_id(room_id, @poem_said_key, 1)
    conn
  end

  defp broadcast_enter_vision(conn, room_id) do
    conn
    |> Helpers.broadcast_vision(room_id, @enter_vision_part1)
    |> Helpers.broadcast_vision(room_id, @enter_vision_part2)
  end

  defp give_wujian(conn) do
    Helpers.give_item(conn, @wujian_item_id)
  end

  defp broadcast_flash_vision(conn, room_id) do
    Helpers.broadcast_vision(conn, room_id, @enter_vision_part3)
  end
end

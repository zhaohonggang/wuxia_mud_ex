defmodule Kantele.World.RoomActions.MessageOnly do
  @moduledoc """
  P5-1b-3 批量机制：数据驱动的「纯消息」房间 handler。

  长尾里大量 `do_*` 只做「输出一段文字」——LPC `write`（只给本人）或
  `message_vision`（房间广播），无状态变更、无属性查询。这些不必各写一个模块，
  集中到本模块的 `@messages` 表，按 `{room_id, verb}` 查表执行。需要真实逻辑
  （改 exits / 查属性 / 战斗 / 技能）的 handler 仍单独写模块（如 `Tiao`/`Clap`，
  以及未来 `Move` 等）。

  支持三种模式：
  - `{:player, text}` — LPC `write(text)`，只推给当前玩家；
  - `{:vision, text}` — LPC `message_vision(text, this_player())`，房间广播（`$N`→行动者名）；
  - `{:vision_args, %{arg => text}}` — 按 `arg`（动词后文本）分支广播，未匹配则不输出
    （对应 LPC `if (arg == "x") message_vision(...)` 的多分支无默认）。

  ## 安全性（P7）
  注册表 `@messages` 的键是 `{room_id, verb}`，只有被 `RoomActionHandlers` 注册到
  对应房间的 handler 才会走到这里；且本表只收录**动词不在全局命令表**的房间动作，
  激活后不影响任何全局命令。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @messages %{
    # d/hangzhou/liuzhuang.c: do_knock —— 敲门无反应（房间广播）
    {"hangzhou:liuzhuang", "knock"} =>
      {:vision, "$N“咚，咚，咚”地敲着门，可里面却一点动静都没有。\n"},
    # d/huanggong/inwell.c: do_reach —— 按 arg 分支（木桶 / 长绳）广播
    {"huanggong:inwell", "reach"} =>
      {:vision_args,
       %{
         "mutong" => "\n$N试著去抓木桶，但总是差一点够着，要能跳高一点就好了。\n",
         "string" => "\n$N试著去抓长绳，但总是差一点够着，要能跳高一点就好了。\n"
       }}
  }

  @impl true
  def run(conn, %{verb: verb, trailing: trailing, room_id: room_id}) do
    case Map.get(@messages, {room_id, verb}) do
      {:player, text} -> Helpers.render_to_player(conn, text)
      {:vision, text} -> Helpers.broadcast_vision(conn, room_id, text)
      {:vision_args, map} -> run_vision_args(conn, room_id, map, trailing)
      _ -> conn
    end
  end

  defp run_vision_args(conn, room_id, map, trailing) do
    case Map.get(map, String.trim(trailing || "")) do
      text when is_binary(text) -> Helpers.broadcast_vision(conn, room_id, text)
      _ -> conn
    end
  end

  @doc "已配置的 `{room_id, verb}` 条目列表（覆盖度统计用）。"
  def entries(), do: Map.keys(@messages)
end

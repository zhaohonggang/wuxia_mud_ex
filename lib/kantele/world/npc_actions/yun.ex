defmodule Kantele.World.NpcActions.Yun do
  @moduledoc """
  P5-1c-3 首个 NPC 样板：`yun`（私有动词）。

  对应 LPC `do_yun(string arg)`：
    - `arg == "roar"` → `message_vision` 向房间广播一条 NPC 喝道文案，
      `return 1`（拦截，不放行全局命令）；
    - 其它 `arg`（含空） → `return 0`（不处理，放行全局命令 / 未知命令）。

  纯输出，零状态变更，是 NPC 私有动作通道的理想首个样板。

  ## 与 LPC 的对应

  LPC 里各 NPC 的 `do_yun` 文案各不相同（殷素素 / 赵敏 …），本模块按
  `npc.name` 查表取文案，未收录的 NPC 使用按姓名渲染的默认文案。
  文案里不含 `$N`，故直接广播，不经 `{npc}` 占位符替换（与
  `Helpers.broadcast_vision/3` 的 `$N` → `{npc}` 归一化无冲突）。
  """
  use Kantele.World.NpcAction

  alias Kantele.World.RoomActions.Helpers

  # 按 npc.name 索引的 vision 文案（与 LPC do_yun 逐 NPC 一致）。
  @messages %{
    "殷素素" => "\n殷素素喝道：贼子，要想行凶么？在这里恐怕由不得你！\n"
  }

  @impl true
  def run(conn, %{verb: _, trailing: trailing, room_id: room_id, npc: npc}) do
    cond do
      not is_binary(room_id) ->
        :not_handled

      String.trim(trailing || "") == "roar" ->
        text = Map.get(@messages, npc.name, default_message(npc.name))
        Helpers.broadcast_vision(conn, room_id, text)

      true ->
        # LPC `return 0`：本次输入不处理，放行全局命令（此处 "yun" 并非
        # 全局命令，故玩家会收到未知命令提示；在未注册房间则不受影响）
        :not_handled
    end
  end

  defp default_message(name) when is_binary(name) do
    "\n#{name}喝道：无耻贼子，在我这儿由不得你猖狂！\n"
  end

  defp default_message(_), do: "\n此人喝道：无耻贼子，在我这儿由不得你猖狂！\n"
end

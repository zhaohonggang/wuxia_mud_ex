defmodule Kantele.World.RoomActions.Huashan.Lianhua.Tiao do
  @moduledoc """
  P5-1b-3 端到端样板：移植自 `d/huashan/lianhua.c` 的 `do_tiao`。

  LPC 源（已回源核对）：

      int do_tiao()
      {
      //      object me = this_player();
              write(@LONG
      但见远处峭壁如一座极大的屏风，冲天而起，峭壁中部离地约二十馀丈处，生
      著一块三四丈见方的大石，便似一个平台，石上隐隐刻得有字。极目上望，瞧
      清楚乃是「剑冢」（jianzhong）两个大字。
      LONG);
              return 1;
      }

  ## 移植要点
  - LPC `write(...)` = 只发给**当前玩家**的文本。Elixir 侧把文本推入 `conn.output`
    （仅本人可见），由 `CommandController` 在 dispatch 命中后统一 flush + prompt。
  - 动词 `"tiao"` 在全局命令表（`lib/kantele/character/commands.ex`）里**没有注册**，
    故本 handler 仅在 `huashan:lianhua` 房间内拦截，不影响任何全局命令（P7 安全）。
  - 无参、无状态、无副作用 —— 是验证「分发链路真触发」的最小闭环样板。
  """
  use Kantele.World.RoomAction

  @text """
  但见远处峭壁如一座极大的屏风，冲天而起，峭壁中部离地约二十馀丈处，生著一块三四丈见方的大石，便似一个平台，石上隐隐刻得有字。极目上望，瞧清楚乃是「剑冢」（jianzhong）两个大字。\
  """

  @impl true
  def run(conn, _params) do
    Kantele.World.RoomActions.Helpers.render_to_player(conn, @text)
  end
end

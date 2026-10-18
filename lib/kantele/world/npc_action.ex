defmodule Kantele.World.NpcAction do
  @moduledoc """
  NPC `add_action` handler 行为契约(P5-1c)。

  每个从 LPC NPC `add_action(verb, "do_*")` 移植来的 NPC 私有动词处理函数
  实现本行为。handler 接收 `conn` 与 `params`，必须返回更新后的 `conn`：

      defmodule Kantele.World.NpcActions.Yun do
        use Kantele.World.NpcAction
        def run(conn, %{verb: verb, trailing: trailing, npc: npc}) do
          # ... 处理逻辑 ...
          conn
        end
      end

  `params` 字段：
  - `:verb` — 玩家输入的动词（与 NPC `meta.init.add_actions` 里的 verb 原样匹配）
  - `:trailing` — 动词之后的剩余文本（已 trim，无则为 `""`）；对应 LPC `do_*` 的 `arg`
  - `:room_id` — 当前房间 id（`conn.character.room_id`）
  - `:npc` — 触发该动作的 NPC 角色结构体（`%Kalevala.Character{}`，含 `meta.init.add_actions`）

  ## 返回 `:not_handled`（LPC `return 0`）

  handler 可以返回 `:not_handled`，等价于 LPC `do_*` 里的 `return 0` ——
  「本次输入我不处理，交回命令解析」。分发器会把它当作未命中放行全局命令。

  ## 安全性(P7)

  当前 `NpcActionHandlers.@registry` 仅收录已移植的 NPC 动词，未注册的
  `(room_id, verb)` 经 `lookup/2` 返回 `{:unimplemented, _}`，分发器据此
  给出 `:not_handled` 放行全局命令，**对全局命令零行为影响**。仅当某 NPC
  某 verb 的 handler 被真正移植并注册后，该动作才被拦截激活。
  """
  @callback run(conn :: Kalevala.Character.Conn.t(), params :: map()) ::
              Kalevala.Character.Conn.t() | :not_handled

  defmacro __using__(_opts) do
    quote do
      @behaviour Kantele.World.NpcAction
    end
  end
end

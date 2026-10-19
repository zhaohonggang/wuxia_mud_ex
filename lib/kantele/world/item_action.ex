defmodule Kantele.World.ItemAction do
  @moduledoc """
  物品 `add_action` handler 行为契约（第十二批）。

  每个从 LPC 物品 `add_action(<handler_fn>, <verb>)` 移植来的处理函数实现
  本行为。handler 接收 `conn` 与 `params`，必须返回更新后的 `conn`：

      defmodule Kantele.World.ItemActions.Play do
        use Kantele.World.ItemAction

        def run(conn, %{verb: verb, trailing: trailing, item: item}) do
          # ... 处理逻辑 ...
          conn
        end
      end

  `params` 字段：
  - `:verb` — 玩家输入的动词（与物品 `meta.actions` 里的 `verb` 原样匹配）
  - `:trailing` — 动词之后的剩余文本（已 trim，无则为 `""`）；对应 LPC
    handler 的 `arg`
  - `:room_id` — 当前房间 id（`conn.character.room_id`）
  - `:item` — 触发该动作的物品**定义**（`%Kalevala.World.Item{}`，含
    `meta.actions` / `meta.read_text` / `name` / `meta.aliases`）
  - `:instance` — 该物品的实例（`%Kalevala.World.Item.Instance{}`；背包 /
    房间地上各持一份实例）
  - `:handler` — LPC handler 函数名（`add_action` 第一个参数，如 "play_qin"），
    由 `ItemActionHandlers` 注册表解析到本模块

  ## 返回 `:not_handled`（LPC `return 0`）

  handler 可以返回 `:not_handled`，等价于 LPC handler 里的 `return 0` ——
  「本次输入本对象不处理」。与 NPC 通道不同，物品通道**会继续尝试下一个
  候选物品**（LPC 的 add_action 就是逐个对象调用、第一个 return 1 的胜出），
  例如 `play <song> with <id>` 只有 id 匹配的那个乐器应答。

  ## 安全性(P7)

  `ItemActionHandlers.@registry` 只收录已移植的 handler 名（play_qin/
  play_xiao/play_zheng/do_read）。未注册的 handler 经 `lookup/1` 返回
  `{:unimplemented, _}`，分发器跳过该候选，**对全局命令零行为影响**。
  """

  @callback run(conn :: Kalevala.Character.Conn.t(), params :: map()) ::
              Kalevala.Character.Conn.t() | :not_handled

  defmacro __using__(_opts) do
    quote do
      @behaviour Kantele.World.ItemAction
    end
  end
end

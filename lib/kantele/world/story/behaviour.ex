defmodule Kantele.World.Story.Behaviour do
  @moduledoc """
  剧情模块契约（对应 LPC `daemons/story/*.c` 的 `query_story_message/1` + `prompt/0`）

  - `prompt/0`：每行播报的彩色前缀（如「【武林传闻】」），带 `{color ...}` 标记；
  - `init_state/0`：本场剧情启动时初始化模块内部状态（如选中玩家的 id/name）；
  - `step/2`：给定步进序号与内部状态，返回推进结果：

    - `{:text, text, state}`：全服播报该行；
    - `{:action, fun, state}`：执行 `fun`（掉落/授技/选人）；其返回值若是字符串则再播报一行；
    - `{:done, state}`：剧情结束。

  step 内用到宿主的全局能力（播报、查玩家、掉物品）通过 `Kantele.World.Story` 提供的
  辅助函数完成；模块本身保持无状态，`state` 由宿主 StoryDaemon 存管。
  """

  @type state :: term

  @callback prompt() :: String.t()

  @callback init_state() :: state

  @callback step(non_neg_integer(), state) ::
              {:text, String.t(), state}
              | {:action, (() -> String.t() | nil), state}
              | {:done, state}
end
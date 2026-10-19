defmodule Kantele.World.ItemActionHandlers do
  @moduledoc """
  物品 `add_action` handler 注册表（第十二批）。

  LPC 物品通过 `add_action(<handler_fn>, <verb>)` 注册私有动词（注意参数序：
  函数名在前、动词在后）。loader 已把这两个参数读入物品定义
  `meta.actions`（`%{verb: "play", handler: "play_qin"}`，见
  `scripts/backfill_item_actions.py`）。本模块负责把 **handler 名**解析为
  可执行的 Elixir `{module, function}`，由 `ItemActionDispatcher` 调用。

  ## 注册策略

  与 NPC 通道（按 `room_id` 索引）不同，物品通道的同一动词在不同物品间
  共享同一份 LPC 实现（`inherit/misc/_qin.c` 的 `play_qin` 被 19 个乐器
  inherit），故按 **LPC handler 名**索引：`handler => {module, function}`。
  物品数据的 `handler` 字段本身即是权威分派依据，新增一种乐器只需回填
  UCL，无需改本表。

  ## 安全性(P7)

  未注册的 handler 名经 `lookup/1` 返回 `{:unimplemented, handler}`，
  分发器据此跳过该候选物品（等价 LPC 该对象 `return 0`），**对全局命令
  零行为影响**。仅当某 handler 被真正移植并注册后，对应物品动作才被激活。

  ## 已注册（第十二批）

  - `play_qin` / `play_xiao` / `play_zheng`（演奏）：三份指向
    `Kantele.World.ItemActions.Play`，按 handler 名分派到
    tanqin-jifa / chuixiao-jifa / guzheng-jifa（ guards + 分级文案 +
    `start_busy(3+random(3))`，逐字对 `kungfu/skill/*-jifa.c` 的 `play()`）；
    `do_effect`（曲目技能效果）@todo —— 歌谱技能（bihai-chaosheng 等）在
    Kantele 是 P9 骨架。
  - `do_read`（阅读）：`Kantele.World.ItemActions.Read`，泛型实现 ——
    读书即渲染该物品 `meta.read_text`（回填自 do_read 的 notify_fail 长文案）。
  """

  @registry %{
    "play_qin" => {Kantele.World.ItemActions.Play, :run},
    "play_xiao" => {Kantele.World.ItemActions.Play, :run},
    "play_zheng" => {Kantele.World.ItemActions.Play, :run},
    "do_read" => {Kantele.World.ItemActions.Read, :run}
  }

  @doc "按 LPC handler 名查注册表。返回 `{:ok, {module, function}}` 或 `{:unimplemented, handler}`"
  def lookup(handler) when is_binary(handler) do
    case Map.fetch(@registry, handler) do
      {:ok, target} -> {:ok, target}
      :error -> {:unimplemented, handler}
    end
  end
end

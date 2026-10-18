defmodule Kantele.World.NpcActions.DownHandlers do
  @moduledoc """
  NPC「倒下」处理器注册表（P5-1c，full `bi`）。

  对应 LPC NPC 重写的 `die()` / `unconcious()`。当 NPC 因**条件**（`nishui`/
  `duyan` 等）把气/精拖到 0 时，`Kantele.Character.ConditionDownEvent` 按本表
  查出处决函数并执行（`on_down(conn, %{cause: :qi | :jing})`，`conn` 为 NPC 自身）。

  与 `NpcActionHandlers` 同构：**仅收录已移植**的 NPC，未登记的 alias 返回
  `:not_handled`，对其它 NPC 零行为影响（安全性 P7）。

  以 `character.meta.aliases`（`set_name` 的 id 表）中的首命中别名索引——用全名
  key（如 `"mai jing"`）避免短别名（`"mai"`）与他物冲突。
  """

  @registry %{
    "mai jing" => {Kantele.World.NpcActions.Bi, :on_mai_down},
    "yuan guangbo" => {Kantele.World.NpcActions.Bi, :on_yuan_down}
  }

  @doc "按角色别名查处决函数：`{:ok, {module, function}}` | `:not_handled`"
  def lookup(%{meta: %{aliases: aliases}}) when is_list(aliases) do
    case Enum.find(aliases, &Map.has_key?(@registry, &1)) do
      nil -> :not_handled
      key -> {:ok, Map.fetch!(@registry, key)}
    end
  end

  def lookup(_character), do: :not_handled

  @doc "已登记的别名（测试/诊断用）"
  def registered_aliases, do: Map.keys(@registry)
end

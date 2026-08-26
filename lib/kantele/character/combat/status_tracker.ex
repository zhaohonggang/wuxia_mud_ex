defmodule Kantele.Character.Combat.StatusTracker do
  @moduledoc """
  追踪 NPC 死亡状态的轻量级 ETS 注册表。

  问题：Kalevala 房间的角色列表是进入房间时的快照，NPC 死亡后状态
  变更为 "尸体..." 但房间快照不更新，导致 `dead?/1` 始终返回 false，
  玩家对尸体发起攻击时看到 "看起来XXX想杀死你！" 而非正确提示。

  方案：NPC 死亡/复活时写入/清除 ETS，房间侧 `dead?/1` 同时检查
  ETS 表。
  """

  use GenServer

  @table :kantele_dead_npcs

  # ---- 公共 API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "标记 NPC 死亡"
  def mark_dead(character_id) do
    :ets.insert(@table, {character_id, System.system_time(:millisecond)})
  end

  @doc "清除 NPC 死亡标记（复活时调用）"
  def mark_alive(character_id) do
    :ets.delete(@table, character_id)
  end

  @doc "查询 NPC 是否已死亡"
  def dead?(character_id) do
    :ets.lookup(@table, character_id) != []
  end

  # ---- GenServer 回调 ----

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end
end

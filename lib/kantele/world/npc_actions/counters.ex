defmodule Kantele.World.NpcActions.Counters do
  @moduledoc """
  NPC 私有动作的**共享发放计数**（P5-1c `yao`：钱正伦兵器/护甲）。

  对应 LPC `d/beijing/npc/qianzhenglun.c` 的文件级静态：

      int total = random(15);
      mapping my_count = ([]);

  `total` 每个 NPC 蓝图初始化一次（随机 `0..14`），`my_count[arg]` 累计该 NPC
  对该 `arg` 已发放的数量，达到 `total` 后拒绝（「你要的东西我都已经发完了」）。

  Kantele 没有 LPC 文件级静态；这里按 `room_id`（一房一 NPC）记录
  `%{total, counts}`，进程随世界重载/NPC 重建而重启即复位，与 LPC 蓝图重新
  加载的语义一致。

  ## 安全降级

  进程未启动（如脱离 app 的单测）时，`limit/1` 返回 `:none`（不设上限）、
  `count/2` 返回 `0`、`record/2` 为空操作 —— 调用方无需判断进程是否存在。
  """
  use GenServer

  @name __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, @name))
  end

  @doc "该房间的发放上限（首次访问时按 `random(15)` 初始化）；进程未启动返回 `:none`"
  def limit(room_id) when is_binary(room_id), do: call({:limit, room_id}, :none)

  @doc "该房间对 `arg` 的已发放数量；进程未启动返回 `0`"
  def count(room_id, arg), do: call({:count, room_id, arg}, 0)

  @doc "记一次发放（返回新计数）；进程未启动为空操作"
  def record(room_id, arg), do: call({:record, room_id, arg}, :ok)

  @doc "清空某房间（或 `:all`）计数（测试/世界重载用）"
  def reset(room_id \\ :all), do: call({:reset, room_id}, :ok)

  @doc false
  def put_total(room_id, total) when is_binary(room_id) and is_integer(total),
    do: call({:put_total, room_id, total}, :ok)

  defp call(msg, default) do
    case Process.whereis(@name) do
      pid when is_pid(pid) -> GenServer.call(pid, msg)
      _ -> default
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:limit, room_id}, _from, state) do
    {total, state} = ensure_room(state, room_id)
    {:reply, total, state}
  end

  def handle_call({:count, room_id, arg}, _from, state) do
    {_total, state} = ensure_room(state, room_id)
    {:reply, Map.get(state[room_id].counts, arg, 0), state}
  end

  def handle_call({:record, room_id, arg}, _from, state) do
    {_total, state} = ensure_room(state, room_id)
    room = state[room_id]
    counts = Map.update(room.counts, arg, 1, &(&1 + 1))
    {:reply, counts[arg], Map.put(state, room_id, %{room | counts: counts})}
  end

  def handle_call({:reset, :all}, _from, _state), do: {:reply, :ok, %{}}

  def handle_call({:reset, room_id}, _from, state),
    do: {:reply, :ok, Map.delete(state, room_id)}

  def handle_call({:put_total, room_id, total}, _from, state) do
    {_total, state} = ensure_room(state, room_id)
    room = state[room_id]
    {:reply, :ok, Map.put(state, room_id, %{room | total: total})}
  end

  defp ensure_room(state, room_id) do
    case Map.get(state, room_id) do
      nil ->
        total = :rand.uniform(15) - 1
        {total, Map.put(state, room_id, %{total: total, counts: %{}})}

      %{total: total} = room ->
        {total, state}
    end
  end
end

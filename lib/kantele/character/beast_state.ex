defmodule Kantele.Character.BeastState do
  @moduledoc """
  驯兽运行态存储（LPC NPC 侧 `set_temp("owner"/"owner_id"/"owner_name")` 的等价物）。

  ## 为什么需要独立的表

  LPC 的 `train.c` / `come.c` / `stay.c` / `stop.c` / `release.c` 把「谁驯服了这只
  野兽」「它跟谁走」「它还在咬谁」写在 **NPC 自己的 temp dbase** 上。Ex 侧 NPC 是
  独立进程，玩家命令拿到的是房间里的 `Meta.Trim` 快照
  （`NonPlayerMeta.Trim` 只保留 `:vitals/:stats/:guarder/:aliases/:init`），
  既读不到也写不进 NPC 的私有态；而 `Kalevala.Character.Conn.put_character/2`
  只回写**当前玩家**的 character。

  因此这里用一张受监督 GenServer 持有的 public ETS 表，按 NPC `id` 存驯兽态，
  语义与 LPC 的 `set_temp` 一致：**进程内有效，不落盘，重启/重载世界后清空**。
  玩家侧的 `comedby`（谁跟着我）仍按 LPC 存 `PlayerMeta.temp["comedby"]`。

  ## 单条状态

      %{
        owner_id: "player-1",       # LPC query_temp("owner") / owner_id
        owner_name: "张三",          # LPC owner_name
        leader_id: "player-1",      # LPC set_leader(me) / set_leader(0)
        attitude: "peace",          # LPC set("attitude", "peace")
        ridable: true,              # LPC set("ridable", 1)
        enemies: [],                # LPC remove_all_enemy(1) 清的就是它
        busy: 0                     # LPC is_busy()
      }

  ## 与 FamilyFame 相同的兜底

  读走 `:ets` 直读；服务未启动（例如 `--no-start` 纯函数测试）时读返回空、
  写静默 no-op，命令绝不因服务未起而崩。测试可用 `ensure!/0` 起一个
  链接到当前进程的临时实例。
  """

  use GenServer

  @table :kantele_beast_state

  @default %{
    owner_id: nil,
    owner_name: nil,
    leader_id: nil,
    attitude: nil,
    ridable: false,
    enemies: [],
    busy: 0
  }

  # ---- 进程 ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    {:ok, %{}}
  end

  @doc """
  测试/运维用：确保服务在跑。

  应用监督树正常启动时这是 no-op；纯函数测试（`--no-start`）里会起一个
  **不链接**到调用进程的临时实例。ETS 表由 GenServer 持有，若把实例链接到
  单个 ExUnit 测试进程，该用例一结束进程退出就会连带删表，令并行/后续用例
  读到空表；用 `GenServer.start/3` 起游离实例，整轮测试共用一张表，
  由各用例 `setup` 里的 `reset/0` 做隔离。
  """
  def ensure! do
    if Process.whereis(__MODULE__) do
      :ok
    else
      case GenServer.start(__MODULE__, [], name: __MODULE__) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end
    end
  end

  # ---- 读写 ----

  @doc "空状态模板（`train` 之前的野生 NPC 视作没有任何驯兽态）"
  def empty, do: @default

  @doc "LPC `query_temp(\"owner\")` 等：取某只野兽的驯兽态，未驯服返回 `nil`"
  def get(beast_id) do
    if table_exists?() do
      case :ets.lookup(@table, beast_id) do
        [{^beast_id, state}] -> state
        [] -> nil
      end
    else
      nil
    end
  end

  @doc "取整张表 `%{beast_id => state}`（供 `release` 全房扫描）"
  def all do
    if table_exists?(), do: @table |> :ets.tab2list() |> Map.new(), else: %{}
  end

  @doc "写整条驯兽态"
  def put(beast_id, state) when is_map(state) do
    if table_exists?(), do: :ets.insert(@table, {beast_id, state}), else: false
    :ok
  end

  @doc """
  原子更新一条驯兽态。`fun` 收到当前状态（可能是 `nil`），返回新状态；
  返回 `nil` 时删除该条（`release` 放生用）。
  """
  def update(beast_id, fun) when is_function(fun, 1) do
    if table_exists?() do
      case fun.(get(beast_id)) do
        nil -> :ets.delete(@table, beast_id)
        state -> :ets.insert(@table, {beast_id, Map.merge(@default, state)})
      end
    end

    :ok
  end

  @doc "删除一条驯兽态"
  def delete(beast_id) do
    if table_exists?(), do: :ets.delete(@table, beast_id), else: false
    :ok
  end

  @doc "按主人 id 反查所有已驯服野兽，返回 `[{beast_id, state}]`（`release` 用）"
  def owned_by(owner_id) do
    all()
    |> Enum.filter(fn {_id, state} -> Map.get(state, :owner_id) == owner_id end)
  end

  @doc "清空整张表（测试 / 世界重载）"
  def reset do
    if table_exists?(), do: :ets.delete_all_objects(@table), else: false
    :ok
  end

  defp table_exists?, do: :ets.whereis(@table) != :undefined
end

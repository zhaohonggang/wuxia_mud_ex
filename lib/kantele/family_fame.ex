defmodule Kantele.FamilyFame do
  @moduledoc """
  门派声望服务（`adm/daemons/familyd.c` 的 `family_fame` 部分）。

  LPC 的 `FAMILY_D` 是一个存档 daemon：

  - `create()` 时若没有存档，就用 `base_family_fame` 这张**静态门派声望表**
    初始化（30 个门派，从少林寺 1000 万到镇远镖局 50 万）；
  - `add_family_fame(fname, delta)` 只允许改已存在的门派，声望钳在
    `0..1_000_000_000`；
  - 心跳每 1800 秒检查一次日期，**跨天**时把当天声望复制进
    `last_family_fame`（昨天快照）；`query_all_last_family_fame()` 在没有快照时
    返回今天的声望，所以刚开服时所有 delta 都是 0。

  本模块只移植 `top2` / `topp` 需要的那部分（当前声望 + 昨日快照 + 增减 +
  跨天快照），`family_kill` / 仇恨表属于另一条链，不在本模块范围。跨天由
  `snapshot/0` 显式触发（Ex 侧暂无与 LPC 心跳等价的定时器），并由上层在需要时
  调用；因此本服在调用前 delta 恒为 0，这与 LPC「刚开服 / 无昨日数据」一致。

  ## 为何用 ETS + GenServer

  与 `Kantele.League`（`LEAGUE_D` 等价物）保持一致：ETS 表由受监督的
  GenServer 持有，读走 `:ets` 直读、写走 `GenServer.call`，避免多进程同时
  改声望时丢更新。若进程树尚未启动（例如纯函数测试里 `--no-start`），
  `all/0` 会退回 `@base_family_fame`、`last/0` 退回 `all/0`、写操作静默
  no-op，保证命令永远不会因服务未起而崩。
  """

  use GenServer

  @table :kantele_family_fame
  @last_table :kantele_family_fame_last
  @max_family_fame 1_000_000_000

  # 逐条照抄 adm/daemons/familyd.c:22-58 的 base_family_fame。
  # LPC 里被注释掉的唐门世家/天地会/欧阳世家/绝情谷/商家堡**不**收录。
  @base_family_fame %{
    "少林寺" => 10_000_000,
    "武当派" => 8_000_000,
    "丐帮" => 7_000_000,
    "全真教" => 6_000_000,
    "华山派" => 5_000_000,
    "段氏皇族" => 4_500_000,
    "灵鹫宫" => 4_000_000,
    "慕容世家" => 4_000_000,
    "明教" => 3_500_000,
    "峨嵋派" => 3_000_000,
    "桃花岛" => 2_500_000,
    "逍遥派" => 2_500_000,
    "星宿派" => 2_500_000,
    "昆仑派" => 2_000_000,
    "古墓派" => 1_500_000,
    "红花会" => 1_500_000,
    "雪山剑派" => 1_500_000,
    "五毒教" => 1_400_000,
    "神龙教" => 1_300_000,
    "日月神教" => 1_200_000,
    "衡山派" => 1_100_000,
    "嵩山派" => 1_000_000,
    "关外胡家" => 900_000,
    "中原苗家" => 800_000,
    "铁掌帮" => 700_000,
    "玄冥谷" => 700_000,
    "大轮寺" => 600_000,
    "血刀门" => 600_000,
    "梅庄" => 500_000,
    "镇远镖局" => 500_000
  }

  # ---- 进程 ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---- 查询（对应 FAMILY_D 的 public API） ----

  @doc "LPC `base_family_fame`：静态初始门派声望表"
  def base, do: @base_family_fame

  @doc "LPC `query_family_fame()`（无参）：返回 `%{门派名 => 声望}`"
  def all do
    if table_exists?(@table) do
      @table |> :ets.tab2list() |> Map.new()
    else
      @base_family_fame
    end
  end

  @doc """
  LPC `query_all_last_family_fame()`：昨日快照。

  没有快照时按 LPC 行为返回今天的数据（于是 delta 全为 0）。
  """
  def last do
    if table_exists?(@last_table) do
      case @last_table |> :ets.tab2list() |> Map.new() do
        empty when map_size(empty) == 0 -> all()
        snapshot -> snapshot
      end
    else
      all()
    end
  end

  @doc "按声望降序返回 `[%{name:, fame:}]`（同分按名字升序，保证输出稳定）"
  def ranking do
    all()
    |> Enum.map(fn {name, fame} -> %{name: name, fame: fame} end)
    |> Enum.sort_by(&{-&1.fame, &1.name})
  end

  # ---- 写入 ----

  @doc """
  LPC `add_family_fame(fname, delta)`：只改已存在的门派，钳在 `0..10 亿`。
  未知名静默忽略（与 LPC 的 `undefinedp(family_fame[fname])` 一致）。
  """
  def add_fame(fname, delta) when is_binary(fname) and is_integer(delta) do
    call({:add_fame, fname, delta})
  end

  def add_fame(_, _), do: :ok

  @doc "跨天快照：把当前声望复制进昨日表（`familyd.c:126-133` 的心跳分支）"
  def snapshot, do: call(:snapshot)

  @doc "恢复开服初始状态并清空昨日快照（供测试与运维使用）"
  def reset, do: call(:reset)

  defp call(request) do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, request)
    else
      :ok
    end
  end

  # ---- GenServer ----

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@last_table, [:named_table, :set, :public, read_concurrency: true])
    seed_base()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:add_fame, fname, delta}, _from, state) do
    case :ets.lookup(@table, fname) do
      [] -> :ok
      [{_, fame}] -> :ets.insert(@table, {fname, clamp(fame + delta)})
    end

    {:reply, :ok, state}
  end

  def handle_call(:snapshot, _from, state) do
    :ets.delete_all_objects(@last_table)

    @table
    |> :ets.tab2list()
    |> Enum.each(fn {name, fame} -> :ets.insert(@last_table, {name, fame}) end)

    {:reply, :ok, state}
  end

  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    :ets.delete_all_objects(@last_table)
    seed_base()
    {:reply, :ok, state}
  end

  # ---- helpers ----

  defp seed_base do
    Enum.each(@base_family_fame, fn {name, fame} -> :ets.insert(@table, {name, fame}) end)
  end

  defp clamp(n) when n < 0, do: 0
  defp clamp(n) when n > @max_family_fame, do: @max_family_fame
  defp clamp(n), do: n

  defp table_exists?(name), do: :ets.whereis(name) != :undefined
end

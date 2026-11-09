defmodule Kantele.Character.Pkd do
  @moduledoc """
  屠人场 daemon（PK_D）。

  对应 LPC `adm/daemons/pkd.c`：赛事状态机 + 报名/退赛 + 竞争者查询。

  ## 状态

  - `:none` —— 无赛事（缺省）
  - `:ready` —— 报名期，可 `join` / `quit`
  - `:starting` —— 正在举行，拒绝新报名
  - `:pking` —— 比赛进行中

  运行态用受监督 GenServer 持有的 public ETS 表，语义与 LPC daemon 一致：
  进程内有效，不落盘，重启/重载世界后清空。

  ## 公共 API

  - `is_ready/0`：state == :ready
  - `is_pking/0`：state == :pking
  - `query_all_competitor/0`：全部报名者列表
  - `reject_join/1`：玩家报名门控，返回 `nil`（可报）或错误字符串
  - `join/1`：加入竞争者
  - `quit/1`：退出竞争者
  - `set_state/2`：切换赛事状态

  测试可用 `ensure!/0` 起一个链接到当前进程的临时实例。
  """

  use GenServer

  @table :kantele_pkd

  @default %{
    state: :none,
    competitors: %{}
  }

  # ---- 进程 ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ensure!() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _ -> :ok
    end

    # GenServer 由某条用例 start_link 时，表归该进程所有；用例结束进程退出后
    # 表可能已被回收，而注册名尚未注销（或反之）。此时 ensure!/0 会误以为
    # daemon 已就绪而不再建表，后续写入直接 ArgumentError。这里补一次建表。
    if :ets.whereis(@table) == :undefined do
      # 并发用例可能同时补建同名表；先建者胜，后建者忽略 badarg。
      try do
        :ets.new(@table, [:public, :named_table, read_concurrency: true])
        :ets.insert(@table, {@table, @default})
      rescue
        ArgumentError -> :ok
      end
    end

    :ok
  end

  @impl true
  def init(_opts) do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:public, :named_table, read_concurrency: true])
    end

    :ets.insert(@table, {@table, @default})

    {:ok, nil}
  end

  # ---- 状态查询 ----

  @doc "赛事是否处于报名期（state == :ready）。"
  def is_ready() do
    read_state() |> Map.get(:state) == :ready
  end

  @doc "比赛是否正在进行（state == :pking）。"
  def is_pking() do
    read_state() |> Map.get(:state) == :pking
  end

  @doc "返回全部报名竞争者列表，每条 %{id, name, combat_exp}。"
  def query_all_competitor() do
    state = read_state()
    Map.values(state.competitors)
  end

  @doc "读取当前赛事状态（服务未启动时返回缺省）。"
  def read_state() do
    # daemon 未启动时 ETS 表也不存在：直接 :ets.lookup 会抛 ArgumentError
    # （"the table identifier does not refer to an existing ETS table"），
    # 曾导致 NPC 报名流程 Sign.do_sign 在纯单测里整条崩掉。
    case :ets.whereis(@table) do
      :undefined ->
        @default

      _table ->
        case :ets.lookup(@table, @table) do
          [{table_key, state}] when table_key == @table -> state
          [] -> @default
        end
    end
  end

  # ---- 报名门控 ----

  @doc """
  玩家报名门控（对应 LPC `PK_D->reject_join(me)`）。

  返回 `nil` 表示可报名；返回字符串表示拒绝原因，NPC 会原文播报。
  """
  def reject_join(character) do
    state = read_state()

    cond do
      state.state != :ready ->
        "现在没要举行比赛啊？你跑来干什么？"

      Map.has_key?(state.competitors, character.id) ->
        "你已经报名过了，别再凑热闹了。"

      true ->
        nil
    end
  end

  # ---- 报名 / 退赛 ----

  @doc "将玩家加入竞争者列表（state 必须为 :ready）。"
  def join(character) do
    state = read_state()

    cond do
      state.state != :ready ->
        {:error, "现在没要举行比赛啊？你跑来干什么？"}

      Map.has_key?(state.competitors, character.id) ->
        {:error, "你已经报名过了，别再凑热闹了。"}

      true ->
        new_competitors =
          Map.put(state.competitors, character.id,
            %{id: character.id, name: character.name, combat_exp: character.meta.stats.combat_exp})

        write_state(%{state | competitors: new_competitors})
        {:ok, :joined}
    end
  end

  @doc "将玩家从竞争者列表中移除。"
  def quit(character) do
    state = read_state()

    new_competitors = Map.delete(state.competitors, character.id)

    write_state(%{state | competitors: new_competitors})

    {:ok, :quit}
  end

  # ---- 状态切换 ----

  @doc "切换赛事状态（:none / :ready / :starting / :pking）。"
  def set_state(state) when state in [:none, :ready, :starting, :pking] do
    current = read_state()
    write_state(%{current | state: state})
    :ok
  end

  def set_state(_state), do: {:error, :invalid_state}

  # ---- ETS 内部 ----

  defp write_state(state) do
    # 写路径不做「表不存在就静默」兜底：那会让 set_state/join 在 daemon 尚未
    # 就绪时悄悄丢状态（曾导致 pkd 命令用例偶发读到 :none）。调用方约定表已由
    # init/1 或测试 reset_pkd/0 建好；仅有读路径需要缺省降级。
    :ets.insert(@table, {@table, state})
    :ok
  end
end

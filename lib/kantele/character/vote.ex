defmodule Kantele.Character.Vote do
  @moduledoc """
  投票 daemon（Vote_D）。

  对应 LPC `cmds/std/vote.c` 与 `/cmds/std/vote/{chblk,unchblk}.c`：
  投票动议创建 + 附议/计票 + 超时自动取消。

  ## 动议类型

  - `chblk`：关闭某人频道（需 3 票以上通过）
  - `unchblk`：打开某人频道（需 3 票以上通过）

  运行态用受监督 GenServer 持有的 public ETS 表，语义与 LPC daemon 一致：
  进程内有效，不落盘，重启/重载世界后清空。

  ## 公共 API

  - `is_voting?/0`：是否有进行中的动议
  - `query_all_votes/0`：全部进行中的动议列表
  - `create_vote/3`：发起投票动议（initiator, act, victim_name）
  - `cast_vote/2`：对进行中动议附议（voter, vote_id）
  - `tally/1`：计票，判定通过/失败（vote_id）
  - `cancel_vote/1`：取消动议（vote_id）

  测试可用 `ensure!/0` 起一个链接到当前进程的临时实例。
  """

  use GenServer

  @table :kantele_vote

  @default %{
    votes: %{}
  }

  @acts ~w[chblk unchblk]

  @pass_threshold 3

  # ---- 进程 ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ensure!() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _ -> :ok
    end
  end

  @impl true
  def init(_opts) do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:public, :named_table, read_concurrency: true])
    end

    :ets.insert(@table, {@table, @default})

    {:ok, nil}
  end

  # ---- 查询 ----

  @doc "是否有进行中的投票动议。"
  def is_voting?() do
    read_state()
    |> Map.get(:votes)
    |> Map.values()
    |> Enum.any?(&(&1.status == :active))
  end

  @doc "返回全部进行中的投票动议，每条 %{id, act, victim, initiator, initiator_name, voters, created_at, status}。"
  def query_all_votes() do
    read_state()
    |> Map.get(:votes)
    |> Map.values()
    |> Enum.filter(&(&1.status == :active))
  end

  @doc "读取当前 daemon 状态（服务未启动时返回缺省）。"
  def read_state() do
    case :ets.lookup(@table, @table) do
      [{table_key, state}] when table_key == @table -> state
      [] -> @default
    end
  end

  # ---- 发起动议 ----

  @doc """
  发起投票动议（对应 LPC `vote <act> <victim>`）。

  返回 `{:ok, vote_id}`；若同一动议已在进行中，返回 `{:error, :already_active, vote_id}`，
  供调用方转而 `cast_vote/2` 附议。
  """
  def create_vote(initiator, act, victim_name) when is_binary(act) and is_binary(victim_name) do
    state = read_state()

    cond do
      act not in @acts ->
        {:error, :invalid_act}

      Enum.any?(state.votes, fn {_, v} ->
        v.act == act and v.victim == victim_name and v.status == :active
      end) ->
        {vote_id, _} =
          state.votes
          |> Enum.find(fn {_, v} -> v.act == act and v.victim == victim_name and v.status == :active end)

        {:error, :already_active, vote_id}

      true ->
        vote_id = "#{act}:#{victim_name}:#{:erlang.unique_integer([:positive])}"

        vote = %{
          id: vote_id,
          act: act,
          victim: victim_name,
          initiator: initiator.id,
          initiator_name: initiator.name,
          voters: %{initiator.id => initiator.name},
          created_at: System.system_time(:second),
          tally: 0,
          tallied_at: nil,
          status: :active
        }

        write_state(%{state | votes: Map.put(state.votes, vote_id, vote)})
        {:ok, vote_id}
    end
  end

  # ---- 附议 ----

  @doc "对进行中的动议附议（voter 为角色结构体）。"
  def cast_vote(voter, vote_id) do
    state = read_state()

    case Map.get(state.votes, vote_id) do
      nil ->
        {:error, :not_found}

      %{status: :active, voters: voters, initiator: initiator} = vote ->
        cond do
          voter.id == initiator ->
            {:error, :initiator_vote}

          Map.has_key?(voters, voter.id) ->
            {:error, :already_voted}

          true ->
            new_voters = Map.put(voters, voter.id, voter.name)
            new_vote = %{vote | voters: new_voters}

            write_state(%{state | votes: Map.put(state.votes, vote_id, new_vote)})
            {:ok, :voted}
        end

      _vote ->
        {:error, :finished}
    end
  end

  # ---- 计票 ----

  @doc "计票：判定动议通过或失败，返回 `{:ok, :passed, yes_count}` 或 `{:ok, :failed, yes_count}`。"
  def tally(vote_id) do
    state = read_state()

    case Map.get(state.votes, vote_id) do
      nil ->
        {:error, :not_found}

      %{status: :active, voters: voters, act: _act} = vote ->
        yes_count = map_size(voters)
        result = if yes_count >= @pass_threshold, do: :passed, else: :failed

        new_vote = %{vote | status: result, tally: yes_count, tallied_at: System.system_time(:second)}

        write_state(%{state | votes: Map.put(state.votes, vote_id, new_vote)})

        {:ok, result, yes_count}

      _vote ->
        {:error, :finished}
    end
  end

  # ---- 取消 ----

  @doc "取消动议。"
  def cancel_vote(vote_id) do
    state = read_state()

    case Map.get(state.votes, vote_id) do
      nil -> :ok
      %{} ->
        write_state(%{state | votes: Map.delete(state.votes, vote_id)})
        :ok
    end
  end

  # ---- ETS 内部 ----

  defp write_state(state) do
    :ets.insert(@table, {@table, state})
    :ok
  end
end

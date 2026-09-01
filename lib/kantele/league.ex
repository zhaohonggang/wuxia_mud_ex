defmodule Kantele.League do
  @moduledoc """
  结社（帮派）全局服务（对应 `adm/daemons/leagued.c`）

  使用 ETS 存储全服同盟数据，键为同盟名（league_name）。
  每个同盟记录：

  - `fname`       ：同盟名
  - `member`      ：成员 id 列表
  - `time`        ：创建时间（秒）
  - `leader_id`   ：领袖 id
  - `leader_name` ：领袖名
  - `fame`        ：同盟声望（LEAGUE_D league_fame）
  - `hatred`      ：`%{id => [name, 仇恨度]}` 仇人表

  ## 成员个人状态
  每个玩家的 `meta.league` 存 `%{league_name, leader_id, leader_name, grant, set}`：
  - `grant`：权限 0..4（0 无权限，1 add，2 kill，3 kick，4 预留 head）
  - `set`   ：`%{no_kill: 0|1, weiwang: 0..100, follow: 0|1}` 个人设置

  权限递增：拥有 higher grant 既拥有其下的全部权限。
  """

  use GenServer

  require Logger

  @table :kantele_leagues
  @max_league_fame 1_000_000_000
  @max_hatred_person 100
  @hatredp_removed 10

  # ---- GenServer API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "列出所有同盟记录"
  def all_leagues, do: :ets.tab2list(@table) |> Enum.map(fn {_k, v} -> v end)

  @doc "查询同盟成员 id 列表（参数可为同盟名或 %{league_name: name} / %{meta: %{league: ...}}）"
  def query_members(fname) when is_binary(fname) do
    case :ets.lookup(@table, fname) do
      [{_, record}] -> record.member
      [] -> nil
    end
  end

  def query_members(%{league_name: fname}), do: query_members(fname)
  def query_members(%{meta: %{league: %{league_name: fname}}}), do: query_members(fname)
  def query_members(%{meta: %{league: nil}}), do: nil
  def query_members(_), do: nil

  @doc "查询同盟声望（参数可为同盟名或角色）"
  def query_league_fame(fname) when is_binary(fname) do
    case :ets.lookup(@table, fname) do
      [{_, record}] -> record.fame || 0
      [] -> 0
    end
  end

  def query_league_fame(%{league_name: fname}), do: query_league_fame(fname)
  def query_league_fame(%{meta: %{league: %{league_name: fname}}}), do: query_league_fame(fname)
  def query_league_fame(%{meta: %{league: nil}}), do: 0
  def query_league_fame(_), do: 0

  @doc "按声望降序返回所有同盟（用于 top league）"
  def ranking do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.sort_by(&(-(&1.fame || 0)))
  end

  @doc "检查同盟名是否可创建（返回 nil=可创建，否则错误消息）"
  def valid_new_league(fname) when is_binary(fname) do
    GenServer.call(__MODULE__, {:valid_new_league, fname})
  end

  @doc "创建同盟（leader 为领队角色/角色 map；base 为初始声望）"
  def create_league(fname, base, leader, leader_id, leader_name) do
    GenServer.call(
      __MODULE__,
      {:create_league, fname, base, leader, leader_id, leader_name}
    )
  end

  @doc "解散同盟"
  def dismiss_league(fname) when is_binary(fname) do
    GenServer.call(__MODULE__, {:dismiss_league, fname})
  end

  @doc "把某成员加入同盟"
  def add_member_into_league(fname, id) do
    GenServer.call(__MODULE__, {:add_member, fname, id})
  end

  @doc "从同盟移除某成员；若移除后无人则解散同盟"
  def remove_member_from_league(fname, id) do
    GenServer.call(__MODULE__, {:remove_member, fname, id})
  end

  @doc "改变同盟声望"
  def add_league_fame(fname, delta) when is_binary(fname) do
    GenServer.call(__MODULE__, {:add_league_fame, fname, delta})
  end

  def add_league_fame(%{league_name: fname}, delta), do: add_league_fame(fname, delta)
  def add_league_fame(%{meta: %{league: %{league_name: fname}}}, delta), do: add_league_fame(fname, delta)
  def add_league_fame(_, _), do: :ok

  @doc "查询同盟仇恨表"
  def query_league_hatred(fname) when is_binary(fname) do
    case :ets.lookup(@table, fname) do
      [{_, record}] -> record.hatred || %{}
      [] -> %{}
    end
  end

  @doc "记录一次同盟间仇杀（killer/victim 为 %Kalevala.Character{} 或角色 map）"
  def league_kill(killer, victim) do
    GenServer.call(__MODULE__, {:league_kill, killer, victim})
  end

  @doc "清除所有同盟对某 id 的仇恨记录"
  def remove_hatred(id) when is_binary(id) do
    GenServer.call(__MODULE__, {:remove_hatred, id})
  end

  def find_league_by_leader(leader_id) do
    @table
    |> :ets.tab2list()
    |> Enum.find(fn {_k, v} -> v.leader_id == leader_id end)
    |> case do
      {_, record} -> record
      nil -> nil
    end
  end

  # ---- GenServer Implementation ----

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:valid_new_league, fname}, _from, state) do
    reply =
      cond do
        league_exists?(fname) ->
          "人家早就有叫这个的啦，你就别凑热闹了。\n"

        league_reserved?(fname) ->
          "江湖上已经有#{fname}了，你还想做什么？\n"

        true ->
          nil
      end

    {:reply, reply, state}
  end

  def handle_call({:create_league, fname, base, _leader, leader_id, leader_name}, _from, state) do
    if league_exists?(fname) do
      {:reply, {:error, :exists}, state}
    else
      record = %{
        fname: fname,
        member: [leader_id],
        time: System.system_time(:second),
        leader_id: leader_id,
        leader_name: leader_name,
        fame: clamp_fame(base),
        hatred: %{}
      }

      true = :ets.insert(@table, {fname, record})
      {:reply, :ok, state}
    end
  end

  def handle_call({:dismiss_league, fname}, _from, state) do
    :ets.delete(@table, fname)
    {:reply, :ok, state}
  end

  def handle_call({:add_member, fname, id}, _from, state) do
    result =
      case :ets.lookup(@table, fname) do
        [] ->
          {:error, :no_such}

        [{_, record}] ->
          if id in record.member do
            {:error, :already_member}
          else
            record = %{record | member: record.member ++ [id]}
            :ets.insert(@table, {fname, record})
            :ok
          end
      end

    {:reply, result, state}
  end

  def handle_call({:remove_member, fname, id}, _from, state) do
    result =
      case :ets.lookup(@table, fname) do
        [] ->
          {:error, :no_such}

        [{_, record}] ->
          members = List.delete(record.member, id)

          if members == [] do
            :ets.delete(@table, fname)
            {:ok, :dissolved}
          else
            :ets.insert(@table, {fname, %{record | member: members}})
            :ok
          end
      end

    {:reply, result, state}
  end

  def handle_call({:add_league_fame, fname, delta}, _from, state) do
    case :ets.lookup(@table, fname) do
      [] ->
        {:reply, :ok, state}

      [{_, record}] ->
        new_fame = clamp_fame((record.fame || 0) + delta)
        :ets.insert(@table, {fname, %{record | fame: new_fame}})
        {:reply, :ok, state}
    end
  end

  def handle_call({:league_kill, killer, victim}, _from, state) do
    do_league_kill(killer, victim)
    {:reply, :ok, state}
  end

  def handle_call({:remove_hatred, id}, _from, state) do
    :ets.tab2list(@table)
    |> Enum.each(fn {fname, record} ->
      if record.hatred && Map.has_key?(record.hatred, id) do
        hatred = Map.delete(record.hatred, id)
        :ets.insert(@table, {fname, %{record | hatred: hatred}})
      end
    end)

    {:reply, :ok, state}
  end

  # ---- helpers ----

  defp clamp_fame(n) when n < 0, do: 0
  defp clamp_fame(n) when n > @max_league_fame, do: @max_league_fame
  defp clamp_fame(n), do: n

  defp league_exists?(fname), do: :ets.member(@table, fname)

  # 与门派/家族名冲突则不可用（LPC 查 FAMILY_D；此处用家族字段兜底）
  defp league_reserved?(_fname), do: false

  # 同盟间仇杀（LEAGUE_D->league_kill/2）
  defp do_league_kill(killer, victim) do
    kfam = league_name_of(killer)
    vfam = league_name_of(victim)

    if is_nil(kfam) and is_nil(vfam), do: :ok

    kexp = combat_exp(killer)
    vexp = combat_exp(victim)

    fame_delta =
      if kexp < vexp * 3 and vexp >= 100_000 do
        div(vexp + score(killer) * 2 + weiwang(killer) * 10, 1000)
      else
        0
      end

    # 杀手同盟对死者的仇恨加分
    fame_delta =
      if kfam do
        case :ets.lookup(@table, kfam) do
          [{_, record}] ->
            vid = id_of(victim)
            hatred = record.hatred || %{}

            if data = Map.get(hatred, vid) do
              [_name, lvl] = data
              bonus = div(lvl, 3)
              fame_delta = fame_delta + bonus

              new_lvl = lvl - fame_delta

              if new_lvl <= 0 do
                :ets.insert(@table, {kfam, %{record | hatred: Map.delete(hatred, vid)}})
              else
                :ets.insert(@table, {kfam, %{record | hatred: Map.put(hatred, vid, [name_of(killer), new_lvl])}})
              end

              fame_delta
            else
              fame_delta
            end

          [] ->
            fame_delta
        end
      else
        fame_delta
      end

    # 调整两盟声望
    if kfam, do: add_league_fame(kfam, fame_delta)
    if vfam, do: add_league_fame(vfam, -fame_delta)

    # 记录死盟对杀手的仇恨
    if vfam do
      add_hatred(vfam, id_of(killer), name_of(killer), vexp_to_hatred(vexp))
    end

    :ok
  end

  defp vexp_to_hatred(vexp) do
    v = div(vexp, 1000) + 1

    cond do
      v > 5000 -> div(v - 5000, 16) + 2000
      v > 1000 -> div(v - 1000, 4) + 1000
      true -> v
    end
  end

  defp add_hatred(fname, id, name, lvl) do
    case :ets.lookup(@table, fname) do
      [] ->
        :ok

      [{_, record}] ->
        hatred = record.hatred || %{}

        hatred =
          if Map.has_key?(hatred, id) do
            Map.put(hatred, id, [name, Kernel.elem(Map.get(hatred, id), 1) + lvl])
          else
            if map_size(hatred) >= @max_hatred_person do
              # 移除仇恨度最低的若干条（简化：按仇恨度排序）
              hatred
              |> Enum.sort_by(fn {_id, [_n, l]} -> l end)
              |> Enum.drop(@hatredp_removed)
              |> Map.new()
              |> Map.put(id, [name, lvl])
            else
              Map.put(hatred, id, [name, lvl])
            end
          end

        :ets.insert(@table, {fname, %{record | hatred: hatred}})
    end
  end

  defp league_name_of(%{meta: %{league: %{league_name: f}}}), do: f
  defp league_name_of(%{league_name: f}), do: f
  defp league_name_of(_), do: nil

  defp id_of(%{id: id}), do: id
  defp id_of(_), do: nil

  defp name_of(%{name: name}), do: name
  defp name_of(_), do: "?"

  defp combat_exp(%{meta: %{stats: %{combat_exp: v}}}), do: v || 0
  defp combat_exp(_), do: 0

  defp score(%{meta: %{stats: %{score: v}}}), do: v || 0
  defp score(_), do: 0

  defp weiwang(%{meta: %{stats: %{weiwang: v}}}), do: v || 0
  defp weiwang(_), do: 0
end

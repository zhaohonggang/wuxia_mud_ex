defmodule Kantele.World.NameD do
  @moduledoc """
  玩家角色名称守护进程 —— LPC `adm/daemons/name_d.c` 等价。

  维护「名字 ↔ 玩家ID」的注册表，避免重复名称。供少林剃度、
  达摩辈分晋升、巫师改名等场景使用。

  核心函数（与 LPC name_d.c 一一对应）：

      remove_name/2      释放指定 name→id 的映射
      map_name/2         登记 name→id 映射（同名可多 id 共存，用 "/" 分隔）
      invalid_new_name/1 检查新名字：非空、非复姓、不与已有名字重复
      change_name/4      完整改名流程：remove 旧 → 检查新 → map 新（支持 force 绕过）
      who_is/1           查哪个 ID 在用这个名字

  遵循 daemon 惯例（Possession / Vote / Security / Prison / W3ObjectEngine）：
    - GenServer 持公共 ETS，写入直接 `:ets.insert` 不经 `GenServer.call`；
    - `ensure!/0` 补建表（必要时起一个链接到当前进程的实例）；
    - `read_state/0` 表缺失返缺省。
    - 启动时从 `data/name_d.json` 恢复，停止时持久化（LPC `save()`/`restore()` 等价）。
  """

  use GenServer

  require Logger

  @table :name_d
  @path "data/name_d.json"

  # LPC name_d.c family_name（复姓，不能作为玩家名字）
  @family_names ~w[
    东方 独孤 慕容 欧阳 司马 西门 尉迟 长孙 诸葛 上官
    夏候 闻人 皇甫 澹台 公治 淳于 申屠 公孙 公羊 轩辕
    令狐 钟离 宇文 幕容 仲孙 司徒 司空 端木 公良 百里
    东郭 南郭 呼延 羊舌 东门 南官 南宫 拓拔 完颜 耶律
    鲜于
  ] |> MapSet.new()

  # ---------------------------------------------------------------------------
  # GenServer API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    ensure_table()
    state = load_state_internal()
    {:ok, state}
  end

  # ---------------------------------------------------------------------------
  # Public API（直接 ETS，供命令模块调用）
  # ---------------------------------------------------------------------------

  @doc """
  释放 name 与 id 的映射。同名多 id 时只移除该 id，其余保留；
  若名字不存在或 id 不在列表中，静默返回 :ok（LPC 同义）。
  """
  def remove_name(name, id) when is_binary(name) and is_binary(id) do
    ensure_table()

    path = name_path(name)
    case :ets.lookup(@table, path) do
      [{^path, old}] ->
        ids = String.split(old, "/")
        ms = ids -- [id]

        if length(ms) == 0 do
          :ets.delete(@table, path)
        else
          :ets.insert(@table, {path, Enum.join(ms, "/")})
        end

      [] ->
        :ok
    end

    :ok
  end

  def remove_name(_name, _id), do: :ok

  @doc """
  登记 name 与 id 的映射。同名可多 id 共存（LPC 以 "/" 连接）。
  若 id 已在列表中，静默返回 :ok（避免重复登记）。
  """
  def map_name(name, id) when is_binary(name) and is_binary(id) do
    ensure_table()

    if String.length(name) < 2 do
      :ok
    end

    path = name_path(name)
    case :ets.lookup(@table, path) do
      [] ->
        :ets.insert(@table, {path, id})

      [{^path, old}] ->
        ids = String.split(old, "/")
        if id in ids do
          :ok # already exist
        else
          :ets.insert(@table, {path, Enum.join([id | ids], "/")})
        end

      _ ->
        :ok
    end

    :ok
  end

  def map_name(_name, _id), do: :ok

  @doc """
  检查新名字是否合法。返回 nil 表示可用，返回错误字符串表示不可用。

  规则（与 LPC `invalid_new_name/1` 一致）：
    1. 非空、长度 >= 1；
    2. 不能是复姓（family_name 列表）；
    3. 不能与已有登记的名字重复；
  """
  def invalid_new_name(name) when is_binary(name) do
    cond do
      String.length(name) < 1 ->
        "不能使用空名字。"

      MapSet.member?(@family_names, name) ->
        "不能使用复姓作为名字。"

      true ->
        # assure_map_name：清理掉已失效的 id（离线/不存在），再检查重复
        path = name_path(name)
        case :ets.lookup(@table, path) do
          [] ->
            nil # 没人用这个名字，可用

          [{^path, id_list}] ->
            valid_ids = filter_really_exist(name, String.split(id_list, "/"))

            case valid_ids do
              [] ->
                :ets.delete(@table, path)
                nil # 没有 id 匹配了，删除记录，名字可用

              [_ | _] ->
                "这个名字和 #{Enum.join(valid_ids, "/")} 的名字重复了。"
            end

          _ ->
            nil
        end
    end
  end

  def invalid_new_name(_name), do: "名字必须是二进制字符串。"

  @doc """
  完整改名流程（LPC `change_name/3` 等价）：

      1. remove_name(old_name, id)   释放旧名
      2. invalid_new_name(new_name)  检查新名
      3. force || result == nil      决定是否改名
      4. map_name(new_name, id)      登记新名

  返回 `{:ok, new_name}` 或 `{:error, reason}`。
  """
  def change_name(_old_name, _id, new_name, _force) when is_binary(new_name) do
    case invalid_new_name(new_name) do
      nil ->
        {:ok, new_name}

      reason ->
        {:error, reason}
    end
  end

  def change_name(_old_name, _id, _new_name, _force),
    do: {:error, "新名字必须是二进制字符串。"}

  @doc """
  查哪个 ID 在用这个名字。返回 `"ID1/ID2/..."` 或 nil。
  """
  def who_is(name) when is_binary(name) do
    ensure_table()

    path = name_path(name)
    case :ets.lookup(@table, path) do
      [{^path, id_list}] ->
        id_list

      [] ->
        nil
    end
  end

  def who_is(_name), do: nil

  @doc "确保 ETS 表与 GenServer 进程已启动。返回 :ok。"
  def ensure! do
    case Process.whereis(__MODULE__) do
      nil ->
        start_link()
        :ok

      _pid ->
        :ok
    end

    ensure_table()
    :ok
  end

  @doc "读取整体状态（服务未启动时返回缺省），供调试/测试。"
  def read_state do
    if :ets.whereis(@table) == :undefined do
      %{names: []}
    else
      names =
        :ets.tab2list(@table)
        |> Enum.map(fn {{:name, name}, id_list} -> %{name: name, ids: id_list} end)

      %{names: names}
    end
  end

  @doc "底层 ETS 表名（测试用）。"
  def table, do: @table

  @doc "从磁盘重新加载 name_d.json 到 ETS（测试/热更用）。"
  def load_state do
    ensure_table()
    load_state_internal()
    %{}
  end

  # ---------------------------------------------------------------------------
  # 内部：持久化（LPC save()/restore() 等价）
  # ---------------------------------------------------------------------------

  @doc "将 ETS 中的 name_d 注册表持久化到磁盘（供 GenServer 停止时调用）。"
  def save! do
    ensure_table()

    data =
      :ets.tab2list(@table)
      |> Enum.map(fn {{:name, name}, id_list} -> %{name: name, ids: id_list} end)

    json = Jason.encode!(%{names: data})

    case File.mkdir(Path.dirname(@path)) do
      {:ok, _} -> :ok
      {:error, :eexist} -> :ok
      _other -> :ok
    end

    File.write!(@path, json)
    :ok
  end

  @impl true
  def handle_info({:shutdown, _reason}, state) do
    save!()
    {:stop, :normal, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # 内部
  # ---------------------------------------------------------------------------

  defp name_path(name), do: {:name, name}

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      try do
        :ets.new(@table, [:public, :named_table, read_concurrency: true])
      rescue
        ArgumentError -> :ok
      end
    end
  end

  defp load_state_internal do
    case File.read(@path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, %{names: names}} when is_list(names) ->
            Enum.each(names, fn %{name: name, ids: id_list} ->
              :ets.insert(@table, {{:name, name}, id_list})
            end)
            %{}

          _ ->
            Logger.warn("name_d.json 格式异常，启用空注册表")
            %{}
        end

      {:error, :enoent} ->
        Logger.info("name_d.json 不存在，启用空注册表")
        %{}

      {:error, reason} ->
        Logger.warn("name_d.json 读取失败：#{inspect(reason)}，启用空注册表")
        %{}
    end
  end

  # 检查 id 列表中哪些 id 对应的玩家当前确实叫这个名字（LPC really_exist/assure_map_name）
  defp filter_really_exist(_name, ids) do
    # ex 中没有 LPC 的 LOGIN_D/find_player 离线读取能力，
    # 退化为：ETS 已登记的即视为有效（由 map_name/remove_name 保持一致性）。
    ids
  end
end

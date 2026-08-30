defmodule Kantele.Quest do
  @moduledoc """
  玩家任务进度存储（对应 `mudcore/inherit/user_quest.c` 即 CORE_USER_QUEST）

  `feature/user_quest.c` 只是一行 `inherit CORE_USER_QUEST;` 的 shim，真正的逻辑
  在 CORE_USER_QUEST 里：每个玩家一份纯数据（`toDoList` + `solved`）的任务进度表。
  本模块把它原样移植成**纯不可变状态机**，宿主（QuestEvent / NPC quester / 任务
  引擎）用一个 `state` 累计即可。

  ## 状态
  ```elixir
  %{todo: %{ quest_file => %{killed: %{killed_file => count}, item: %{item_file => count}} },
    solved: [quest_file]}
  ```

  ## quest spec
  C 里的 `quest_file->isQuest()/getKill()/getItem()` 是对象运行时调用，纯端口用
  一个小 map 抽象：
  ```elixir
  %{file: "quest_x", kill: ["怪a", "怪b"], item: ["道具"]}
  ```
  - 有效任务 = `is_map(spec) && is_binary(spec[:file])`（isQuest）
  - `getKill` → `spec[:kill] || []`
  - `getItem` → `spec[:item] || []`

  所有变更函数都返回 `{:ok, state}` 或 `{:error, reason}`；查询函数返回纯值。
  ```

  ## 宿主派发（QUEST_D 级）
  `ask_quest/2` / `cancel_quest/2` 对应 `feature/quester.c` 委托给 QUEST_D 的调用
  （无 spec 参数，无法派发具体任务）。本实现按 NPC 自身的 `meta.quest` 配置应答：
  有发布任务规格则返回该规格/其 file，否则回以友好文案。
  """

  @quest_size 20

  @type quest_spec :: %{file: String.t(), kill: [String.t()], item: [String.t()]}

  @doc "新建空状态"
  def new(), do: %{todo: %{}, solved: []}

  # ---- 查询（getToDoList / getSolved / getToDoListSize）----

  @doc "任务进度表（LPC getToDoList）"
  def get_todo_list(%{todo: todo}), do: todo

  @doc "已解任务表（LPC getSolved）"
  def get_solved(%{solved: solved}), do: solved

  @doc "在办任务数（LPC getToDoListSize）"
  def get_size(%{todo: todo}), do: map_size(todo)

  @doc "某任务进度（LPC getToDo，无此任务返回 nil）"
  def get_todo(%{todo: todo}, quest_file), do: Map.get(todo, quest_file)

  # ---- 增删任务进度（setToDo / delToDo）----

  @doc """
  登记一个在办任务（LPC setToDo）

  - `:invalid` 非有效任务（未通过 isQuest）
  - `:full` 任务已达上限 `#{@quest_size}`
  - `:duplicate` 已在办
  - 成功时初始化 `%{killed: %{}, item: %{}}` 并按 `spec.kill` 预填 0
  """
  def set_todo(state, spec, opts \\ []) do
    quest_size = Keyword.get(opts, :quest_size, @quest_size)

    with :ok <- valid_quest(spec),
         :ok <- check_full(state, quest_size),
         :ok <- check_duplicate(state, spec) do
      killed =
        spec
        |> kill_files()
        |> Map.new(&{&1, 0})

      {:ok,
       %{
         state
         | todo: Map.put(state.todo, spec[:file], %{killed: killed, item: %{}})
       }}
    end
  end

  @doc "移除在办任务（LPC delToDo；无此任务则原样返回）"
  def del_todo(%{todo: todo} = state, quest_file) do
    %{state | todo: Map.delete(todo, quest_file)}
  end

  # ---- 击杀进度（addKilled / getKilled）----

  @doc "累计击杀（LPC addKilled；怪须在 spec.kill 声明过）"
  def add_killed(state, spec, killed_file, amount) do
    nested_update(state, spec, :killed, killed_file, amount, kill_files(spec))
  end

  @doc "查询击杀数（LPC getKilled；无则 0）"
  def get_killed(%{todo: todo}, spec, killed_file) do
    with :ok <- valid_quest(spec),
         %{killed: killed} <- Map.get(todo, spec[:file]) do
      Map.get(killed, killed_file, 0)
    else
      _ -> 0
    end
  end

  # ---- 物品进度（addItem / getItem）----

  @doc "累计收集物品（LPC addItem；物须在 spec.item 声明过）"
  def add_item(state, spec, item_file, amount) do
    nested_update(state, spec, :item, item_file, amount, item_files(spec))
  end

  @doc """
  击杀登记（LPC 侧 `QUEST_D->doKilled` 的本地聚合）

  对每个在办任务，若其声称的击杀对象（`task.killed` 的键，由 `set_todo`
  按 `spec.kill` 预填）包含 `killed_key`，则计数 +1。无需外部再传 spec，
  直接以在办任务的已登记击杀键重建 spec 走 `add_killed/4`。
  """
  def register_kill(%{todo: todo} = state, killed_key) do
    Enum.reduce(todo, {:ok, state}, fn {file, task}, {:ok, acc} ->
      spec = %{file: file, kill: Map.keys(Map.get(task, :killed, %{}))}

      case add_killed(acc, spec, killed_key, 1) do
        {:ok, s} -> {:ok, s}
        _ -> {:ok, acc}
      end
    end)
  end

  @doc "查询物品收集数（LPC getItem；无则 0）"
  def get_item(%{todo: todo}, spec, item_file) do
    with :ok <- valid_quest(spec),
         %{item: item} <- Map.get(todo, spec[:file]) do
      Map.get(item, item_file, 0)
    else
      _ -> 0
    end
  end

  # ---- 已解任务（setSolved / isSolved / delSolved）----

  @doc "标记已解（LPC setSolved；已解/无效则不重复添加）"
  def set_solved(%{solved: solved} = state, spec) do
    with :ok <- valid_quest(spec) do
      if spec[:file] in solved do
        {:ok, state}
      else
        {:ok, %{state | solved: solved ++ [spec[:file]]}}
      end
    end
  end

  @doc "是否已解（LPC isSolved）"
  def is_solved(%{solved: solved}, spec) do
    valid_quest(spec) == :ok && spec[:file] in solved
  end

  @doc "移除已解标记（LPC delSolved；未解则原样返回）"
  def del_solved(%{solved: solved} = state, quest_file) do
    %{state | solved: List.delete(solved, quest_file)}
  end

  # ---- 宿主存根（QUEST_D 级，见 @moduledoc）----

  @doc "请求任务（LPC: QUEST_D->ask_quest(npc, who)）"
  def ask_quest(npc, _who) do
    case Map.get(npc, :meta) do
      %{quest: %{file: file} = quest} when is_binary(file) ->
        {:ok, quest}

      _ ->
        {:error, "老朽手头暂无任务可托付。"}
    end
  end

  @doc "取消任务（LPC: QUEST_D->cancel_quest(npc, who)）"
  def cancel_quest(npc, _who) do
    case Map.get(npc, :meta) do
      %{quest: %{file: file}} when is_binary(file) ->
        {:ok, file}

      _ ->
        {:error, "老朽手头暂无你的任务可作罢。"}
    end
  end

  # ---- 内部辅助 ----

  defp valid_quest(spec) when is_map(spec) do
    if is_binary(spec[:file]), do: :ok, else: {:error, :invalid}
  end

  defp valid_quest(_), do: {:error, :invalid}

  defp check_full(%{todo: todo}, quest_size) do
    if map_size(todo) >= quest_size, do: {:error, :full}, else: :ok
  end

  defp check_duplicate(%{todo: todo}, spec) do
    if Map.has_key?(todo, spec[:file]), do: {:error, :duplicate}, else: :ok
  end

  defp kill_files(spec), do: spec |> Map.get(:kill, []) |> List.wrap()

  defp item_files(spec), do: spec |> Map.get(:item, []) |> List.wrap()

  defp nested_update(%{todo: todo} = state, spec, kind, entry, amount, declared) do
    with :ok <- valid_quest(spec),
         %{} = task <- Map.get(todo, spec[:file]),
         true <- entry in declared do
      inner = Map.get(task, kind, %{})
      inner = Map.update(inner, entry, amount, &(&1 + amount))
      task = Map.put(task, kind, inner)

      {:ok, %{state | todo: Map.put(todo, spec[:file], task)}}
    else
      nil -> {:error, :no_todo}
      false -> {:error, :unknown}
      reason -> {:error, reason}
    end
  end
end
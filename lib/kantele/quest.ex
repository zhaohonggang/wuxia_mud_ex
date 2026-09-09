defmodule Kantele.Quest do
  @moduledoc """
  玩家任务进度存储（对应 `mudcore/inherit/user_quest.c` 即 CORE_USER_QUEST）

  `feature/user_quest.c` 只是一行 `inherit CORE_USER_QUEST;` 的 shim，真正的逻辑
  在 CORE_USER_QUEST 里：每个玩家一份纯数据（`toDoList` + `solved`）的任务进度表。
  本模块把它原样移植成**纯不可变状态机**，宿主（QuestEvent / NPC quester / 任务
  引擎）用一个 `state` 累计即可。

  ## v2 扩展（§15 Q1-T1，对齐 adm/daemons/questd.c 任务元数据）
  - spec 可选字段：`type`（任务类型 kill/letter/deliver/...）、`level`（难度级）、
    `limit`（时限秒，0=无时限）、`repeatable`（可重复接取，默认 `true`）、
    `chain`（前置链，全部须已解 is_solved）、`mutex`（互斥，在办中不得接）、
    `master_name`/`master_id`/`place`（发布人/地点提示）。
  - 玩家层新增 `quest_count`（连续完成计数，供阶梯/里程碑奖励）。
  - todo 项带 `meta`（type/level/master_*/place）、`accepted_at`、`limit`（秒）。

  ## 状态
  ```elixir
  %{todo: %{ quest_file => %{killed: %{killed_file => count},
                              item: %{item_file => count},
                              meta: %{type: "...", level: n},
                              accepted_at: unixts | nil,
                              limit: seconds | 0}},
    solved: [quest_file],
    quest_count: 0}
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
  """

  @quest_size 20

  # 里程碑阶梯（LPC questd.c special_bonus 分档 30/50/100/…/1000，可按玩法调整）
  @milestones [30, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]

  @type quest_spec :: %{file: String.t(), kill: [String.t()], item: [String.t()]}

  @doc "新建空状态"
  def new(), do: %{todo: %{}, solved: [], quest_count: 0}

  # ---- 查询（getToDoList / getSolved / getToDoListSize）----

  @doc "任务进度表（LPC getToDoList）"
  def get_todo_list(%{todo: todo}), do: todo

  def get_todo_list(nil), do: %{}

  @doc "已解任务表（LPC getSolved）"
  def get_solved(%{solved: solved}), do: solved

  def get_solved(nil), do: []

  @doc "在办任务数（LPC getToDoListSize）"
  def get_size(%{todo: todo}), do: map_size(todo)

  def get_size(nil), do: 0

  @doc "某任务进度（LPC getToDo，无此任务返回 nil）"
  def get_todo(%{todo: todo}, quest_file), do: Map.get(todo, quest_file)

  def get_todo(nil, _quest_file), do: nil

  @doc "连续完成计数（LPC quest_count；旧数据缺省 0）"
  def quest_count(state), do: Map.get(state, :quest_count, 0)

  @doc "里程碑阶梯（配置参考，可调）"
  def milestone_ladder(), do: @milestones

  # ---- 增删任务进度（setToDo / delToDo）----

  @doc """
  登记一个在办任务（LPC setToDo；v2 扩展 spec 元数据与前置条件）

  校验顺序：`:invalid`（非有效任务）→ `:full`（达上限）→ `:duplicate`（已在办）→
  `:done`（已解且 `repeatable: false`）→ `:chain_blocked`（前置链未全解）→
  `:mutex_blocked`（互斥任务在办中）。

  - `opts`：`:quest_size`（上限，默认 #{@quest_size}）、`:now`（accepted_at 时间戳，
    默认当前系统秒）、`:limit`（覆盖 spec.limit 的时限秒）
  - 成功时初始化 `%{killed: %{}, item: %{}, meta: ..., accepted_at: ..., limit: ...}`
    并按 `spec.kill` 预填 0
  """
  def set_todo(state, spec, opts \\ []) do
    quest_size = Keyword.get(opts, :quest_size, @quest_size)
    now = Keyword.get(opts, :now, :os.system_time(:second))
    limit = Keyword.get(opts, :limit, spec[:limit] || 0)

    with :ok <- valid_quest(spec),
         :ok <- check_full(state, quest_size),
         :ok <- check_duplicate(state, spec),
         :ok <- check_done(state, spec),
         :ok <- check_chain(state, spec),
         :ok <- check_mutex(state, spec) do
      killed =
        spec
        |> kill_files()
        |> Map.new(&{&1, 0})

      task = %{
        killed: killed,
        item: %{},
        meta: task_meta(spec),
        accepted_at: now,
        limit: limit
      }

      {:ok,
       %{
         state
         | todo: Map.put(state.todo, spec[:file], task)
       }}
    end
  end

  @doc "移除在办任务（LPC delToDo；无此任务则原样返回）"
  def del_todo(%{todo: todo} = state, quest_file) do
    %{state | todo: Map.delete(todo, quest_file)}
  end

  # ---- 前置条件（chain / mutex / repeatable）----

  @doc "前置链是否开放：spec.chain 全部已解（LPC preCondition isSolved）"
  def chain_open?(state, spec) do
    Enum.all?(List.wrap(spec[:chain] || []), fn file -> file in get_solved(state) end)
  end

  @doc "互斥是否开放：spec.mutex 无任一在办中（可自由接取返回 true）"
  def mutex_open?(state, spec) do
    Enum.all?(List.wrap(spec[:mutex] || []), fn file ->
      not Map.has_key?(get_todo_list(state), file)
    end)
  end

  @doc "是否可重复接取（LPC isNewly=1 语义；默认可重复）"
  def repeatable?(spec), do: Map.get(spec, :repeatable, true) == true

  # ---- 序列化（P0 持久化）----

  @doc "序列化为可落盘结构；nil（未初始化）序列化为空状态（含 quest_count）"
  def serialize(nil), do: %{todo: %{}, solved: [], quest_count: 0}

  def serialize(%{todo: todo, solved: solved} = state) do
    todo =
      Enum.into(todo, %{}, fn {file, task} ->
        {to_string(file), task}
      end)

    %{
      todo: todo,
      solved: Enum.map(solved, &to_string/1),
      quest_count: Map.get(state, :quest_count, 0)
    }
  end

  @doc "从落盘结构恢复；兼容旧结构（无 quest_count / 任务无 meta 键）；非法输入回退空状态"
  def deserialize(%{todo: todo, solved: solved} = data) when is_map(todo) and is_list(solved) do
    todo =
      Enum.into(todo, %{}, fn {file, task} ->
        {to_string(file), normalize_task(task)}
      end)

    %{
      todo: todo,
      solved: Enum.map(solved, &to_string/1),
      quest_count: Map.get(data, :quest_count, 0)
    }
  end

  def deserialize(_), do: %{todo: %{}, solved: [], quest_count: 0}

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

  # ---- 超时与取消（v2：LPC questd.c cancel_quest / heartbeat 超时）----

  @doc """
  扫描超时任务（limit>0 且 `accepted_at + limit` 已过则超时）。

  返回 `[{quest_file, task}]`；limit=0 视为无时限永不过期。
  """
  def check_timeout(state, now \\ :os.system_time(:second)) do
    Enum.filter(state.todo, fn {_file, task} ->
      limit = Map.get(task, :limit, 0)
      accepted_at = Map.get(task, :accepted_at)

      is_integer(limit) && limit > 0 && is_integer(accepted_at) && now >= accepted_at + limit
    end)
  end

  @doc """
  取消任务并计算惩罚（LPC questd.c cancel_quest：kill 扣威望/贡献/阅历，letter 扣阅历）。

  返回 `{:ok, new_state, penalty_map}`（penalty 形如 `%{weiwang:, gongxian:, score:}`，
  已按任务 level 放大）或 `{:error, :no_todo}`。惩罚的实际扣减由玩家层应用。
  """
  def cancel_with_penalty(state, quest_file, _opts \\ []) do
    case Map.fetch(state.todo, quest_file) do
      :error ->
        {:error, :no_todo}

      {:ok, task} ->
        type = get_in(task, [:meta, :type]) || "default"
        level = get_in(task, [:meta, :level]) || 1
        factor = max(div(level + 9, 10), 1)

        penalty =
          type
          |> penalty_base()
          |> Map.new(fn {k, v} -> {k, v * factor} end)

        {:ok, %{state | todo: Map.delete(state.todo, quest_file)}, penalty}
    end
  end

  @doc "连续完成计数 +1（成功结算后调用）"
  def bump_quest_count(state, step \\ 1) when is_integer(step) and step > 0 do
    %{state | quest_count: Map.get(state, :quest_count, 0) + step}
  end

  @doc "清零连续完成计数（超时/放弃/失败时调用）"
  def reset_quest_count(state), do: %{state | quest_count: 0}

  @doc """
  里程碑判断：`quest_count` 命中阶梯（#{inspect(@milestones)}）返回 `{:ok, tier}`，否则 `:none`。

  奖励内容由宿主（§15 Q1-T2 reward 层）按 tier 发放（物品档后续）。
  """
  def milestone(quest_count) when is_integer(quest_count) and quest_count > 0 do
    if quest_count in @milestones, do: {:ok, quest_count}, else: :none
  end

  def milestone(_), do: :none

  # ---- 完成验收（v2：交付/击杀阈值判定，owner/回执校验在 NPC 层）----

  @doc """
  完成验收（纯计数门槛，LPC accept_object 的数值部分）：

  - `%{kind: :kill}`：spec.kill 任一已击杀至少 1
  - `%{kind: :item, item: item_file, count: n}`：已收集该物 ≥ n
  - 其余 `:bad_evidence`

  返回 `:ok` 或 `{:error, reason}`。动态校验（首级 owner_id、回执 reply_to 等）
  在 NPC give 层做，不在这里。
  """
  def accept_check(state, spec, evidence) do
    with :ok <- valid_quest(spec) do
      case evidence do
        %{kind: :kill} ->
          if kill_files(spec) |> Enum.any?(&(get_killed(state, spec, &1) >= 1)) do
            :ok
          else
            {:error, :kill_insufficient}
          end

        %{kind: :item, item: item, count: count} ->
          if get_item(state, spec, item) >= (count || 1) do
            :ok
          else
            {:error, :item_insufficient}
          end

        _ ->
          {:error, :bad_evidence}
      end
    end
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

  defp check_done(state, spec) do
    if spec[:file] in get_solved(state) and not repeatable?(spec) do
      {:error, :done}
    else
      :ok
    end
  end

  defp check_chain(state, spec) do
    if chain_open?(state, spec), do: :ok, else: {:error, :chain_blocked}
  end

  defp check_mutex(state, spec) do
    if mutex_open?(state, spec), do: :ok, else: {:error, :mutex_blocked}
  end

  defp task_meta(spec) do
    Map.take(spec, [:type, :level, :master_name, :master_id, :place])
  end

  defp normalize_task(task) when is_map(task) do
    %{
      killed: Map.get(task, :killed) || %{},
      item: Map.get(task, :item) || %{},
      meta: Map.get(task, :meta) || %{},
      accepted_at: Map.get(task, :accepted_at),
      limit: Map.get(task, :limit) || 0
    }
  end

  defp normalize_task(_), do: %{killed: %{}, item: %{}, meta: %{}, accepted_at: nil, limit: 0}

  defp penalty_base("kill"), do: %{score: 50, weiwang: 10, gongxian: 5}
  defp penalty_base("letter"), do: %{score: 20}
  defp penalty_base(_), do: %{score: 10}

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
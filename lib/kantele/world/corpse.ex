defmodule Kantele.World.Corpse do
  @moduledoc """
  尸体容器与狩猎掉落（严格对齐 LPC）。

  ## 对应 LPC 的三段管线

  1. `adm/daemons/chard.c::make_corpse(victim, killer)`
     - `wizardp(victim)` → 不生成尸体；
     - `victim->is_ghost()` → 不生成尸体，把死者背包全部移到 `environment(victim)`
       并 `owner_is_killed(killer)`；
     - 其余（**含玩家**）→ `new(CORPSE_OB)`，`corpse->make_corpse(victim, killer)`。
  2. `clone/misc/corpse.c::make_corpse()`：尸体是容器（`is_container()`），死者
     `all_inventory(victim)` 全部 `move(this_object())`，可用 `get <item> from <corpse>` 取回。
  3. `clone/misc/corpse.c::decay()` 三段：`60s` 腐烂 → `60s` 骸骨 → `30s` 骨灰，
     合计 **150 秒**；最后一段把容器内剩余物品 `move(env)` 后 `destruct()`。

  狩猎战利品另走 `inherit/char/quarry.c::die()` / `snake.c::die()`：
  `item1/2/3`（UCL `drop_a/b/c`）按 `hunting` 技能概率门控，`item->move(me, 1)`
  **直接进击杀者背包**，不是放进尸体、也不是落在地上。判定见
  `Kantele.World.Hunting`，由 `hunting/drops` 事件在击杀者进程内落地。

  ## 为什么单独成模块

  Elixir 端口有**两条**死亡管线，尸体逻辑必须两路都接，否则数据配置根本不会生效：

  - `Kantele.Character.Events.CombatEvent.die/3` —— 正常战斗击杀（主路径）
  - `Kantele.Feature.Damage.die/2` —— `smash` / 房间 `break` 等非战斗致死

  ## 每实例状态放哪里

  `Kalevala.World.Room.Context.new/1` 会把 `item_instance.meta` 经 `Meta.trim/1`
  裁成空 map（`Kalevala.Meta.Trim` 的 Map 实现返回 `%{}`），但**不裁剪**
  `item_instance.item`。因此尸体容器内容存在嵌入定义的 `item.meta.contents`，
  由 `Kantele.World.Room.get_item/2` / `update_item/3` / `take_corpse_item/3`
  读写未裁剪的原值。

  ## 物品 id 解析

  UCL 的 `drop_a = { id = "zhurou" }` 经 `loader.parse_item_ref/1` 后是**短 id**，
  而 `Kantele.World.Items` 缓存的 key 由 `loader.parse_item/4` 生成为
  `"<zone.id>:<key>"`（如 `"clone_lib:zhurou"`）。`ItemCommand` 拾取时又用
  `Items.get!(item_instance.item_id)` 取定义，所以短 id 会同时导致「掉落物找不到」
  与「get 时抛异常」。`resolve_drop_item/1` 负责把短 id 解析成完整 key + 定义。
  """

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Scheduler
  alias Kantele.World.Hunting
  alias Kantele.World.Items
  alias Kantele.World.Room

  @corpse_key "corpse"

  # LPC corpse.c::decay() call_out("decay", 60, 1) → 60 → 30，合计 150s
  @decay_intervals %{1 => 60_000, 2 => 60_000, 3 => 30_000}
  @decay_total_ms 150_000

  @doc """
  在死者所在房间生成尸体容器，并通知击杀者结算狩猎掉落。

  返回 `:ok` / `:error`（房间进程不存在）/ `:skip`（巫师、幽灵态或结构不完整）。
  整段包在 `try/rescue` 里：尸体是副作用，绝不能把死亡结算主流程带崩。
  """
  def spawn(character, killer \\ nil) do
    try do
      case character do
        %{id: id, room_id: room_id} when is_binary(id) and is_binary(room_id) ->
          cond do
            wizard?(character) ->
              :skip

            ghost?(character) ->
              drop_inventory_to_room(character, room_id)
              notify_hunting_drops(character, killer)
              :skip

            true ->
              do_spawn(character, room_id, killer)
          end

        _ ->
          :skip
      end
    rescue
      _ -> :error
    end
  end

  defp do_spawn(character, room_id, killer) do
    # 狩猎战利品与尸体相互独立：LPC quarry.c die() 即使 make_corpse 失败也会
    # 给击杀者发物品，故先通知，再放尸体。
    notify_hunting_drops(character, killer)

    corpse = corpse_instance(character, inventory_of(character))

    case Room.add_item(room_id, corpse) do
      :ok ->
        schedule_decay(room_id, corpse.id, 1)
        :ok

      :error ->
        :error
    end
  end

  @doc "LPC corpse.c 三段腐烂总时长（150 秒），供文档/测试核对"
  def decay_total_ms, do: @decay_total_ms

  @doc """
  纯函数：构造尸体 `Item.Instance`（容器）。

  `item_id` 必须是缓存里真实存在的完整 key（默认 `clone_lib:corpse`），否则
  `get all` / `get 尸体` 里的 `Items.get!(item_instance.item_id)` 会抛
  `Could not find key corpse in cache`。

  `contents` 是死者背包转移进来的 `Item.Instance` 列表（LPC
  `all_inventory(victim)->move(this_object())`）。
  """
  def corpse_instance(character, contents \\ []) do
    drops = drop_item_ids(character)
    key = resolve_corpse_key()
    victim = Map.get(character, :name, "无名")
    name = "#{victim}的尸体"

    item_meta = %{
      # 字符串键保留给既有运行期读取/测试
      "owner_id" => Map.get(character, :id),
      "is_corpse" => true,
      "drop_items" => drops,
      "character_name" => victim,
      # atom 键给消费端（Item.Meta 同款约定）
      :is_corpse => true,
      :no_get => "你搬不动这具尸体。\n",
      :contents => contents || [],
      :decay_phase => 0,
      :victim_name => victim,
      :aliases => ["corpse", "尸体", "尸首"]
    }

    %Instance{
      id: Instance.generate_id(),
      item_id: key,
      created_at: DateTime.utc_now(),
      item: %Item{
        id: key,
        name: name,
        description: "#{name}静静地躺在这里。",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: item_meta
      },
      meta: %{
        "drop_items" => drops,
        "owner_id" => Map.get(character, :id),
        "is_corpse" => true
      }
    }
  end

  @doc """
  纯函数：从 NPC meta 读取 `drop_a` / `drop_b` / `drop_c`（LPC `item1`/`item2`/`item3`）。
  去掉 nil 并去重，返回短 id 列表（由 `resolve_drop_item/1` 再解析成缓存 key）。
  """
  def drop_item_ids(character) do
    meta = Map.get(character, :meta, %{}) || %{}

    [:drop_a, :drop_b, :drop_c]
    |> Enum.map(&Map.get(meta, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  把 UCL 里的短物品引用解析成 `{完整缓存 key, 物品定义}`。

  依次尝试：原样 → `clone_lib:` 前缀 → 缓存中以 `":<短名>"` 结尾的 key。
  缓存 ETS 表不存在时（单元测试、世界未启动）静默返回 nil，不抛异常。
  """
  def resolve_drop_item(item_ref) when is_binary(item_ref) do
    short = item_ref |> String.split(":") |> List.last()

    candidates =
      [
        item_ref,
        if(String.contains?(item_ref, ":"), do: nil, else: "clone_lib:" <> item_ref)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case Enum.find_value(candidates, &fetch_item_pair/1) do
      nil -> find_item_by_suffix(short)
      pair -> pair
    end
  end

  def resolve_drop_item(_), do: nil

  # ---- 尸体容器内容（每实例，存在嵌入 item.meta.contents） ----

  @doc "读取尸体容器内的物品实例列表"
  def contents(%{item: %{meta: meta}} = _instance) when is_map(meta) do
    Map.get(meta, :contents) || Map.get(meta, "contents") || []
  end

  def contents(_), do: []

  @doc "写回尸体容器内容（供 `get ... from ...` 与腐烂末期使用）"
  def put_contents(%{item: %{meta: meta} = item} = instance, contents)
      when is_map(meta) and is_list(contents) do
    %{instance | item: %{item | meta: Map.put(meta, :contents, contents)}}
  end

  def put_contents(instance, _contents), do: instance

  @doc "尸体容器？"
  def corpse?(%{item: %{meta: meta}}) when is_map(meta) do
    Map.get(meta, :is_corpse) == true or Map.get(meta, "is_corpse") == true
  end

  def corpse?(_), do: false

  # ---- 三段腐烂（LPC corpse.c::decay） ----

  @doc "安排某一段腐烂；段号 1/2/3，间隔 60s / 60s / 30s"
  def schedule_decay(room_id, corpse_instance_id, phase)
      when is_binary(room_id) and is_binary(corpse_instance_id) and
             is_integer(phase) and phase >= 1 and phase <= 3 do
    ms = Map.fetch!(@decay_intervals, phase)

    Scheduler.schedule_once(ms, fn ->
      try do
        decay(room_id, corpse_instance_id, phase)
      rescue
        _ -> :ok
      end
    end)
  end

  def schedule_decay(_room_id, _corpse_instance_id, _phase), do: :ok

  @doc """
  执行一段腐烂（对应 LPC `decay(phase)`）。

  - 1 → 改名「腐烂的尸体」+ 房间播报，再排第 2 段；
  - 2 → 改名「枯乾的骸骨」+ 房间播报，再排第 3 段；
  - 3 → 容器内剩余物品全部移到房间地上，移除尸体，播报骨灰文案。
  """
  def decay(room_id, corpse_instance_id, phase) do
    case Room.get_item(room_id, corpse_instance_id) do
      {:ok, corpse} ->
        old_name = corpse_name(corpse)

        case phase do
          1 ->
            Room.update_item(room_id, corpse_instance_id, &decayed(&1, 1))
            tell_room(room_id, "#{old_name}开始腐烂了，发出一股难闻的恶臭。\n")
            schedule_decay(room_id, corpse_instance_id, 2)

          2 ->
            Room.update_item(room_id, corpse_instance_id, &decayed(&1, 2))
            tell_room(room_id, "#{old_name}被风吹乾了，变成一具骸骨。\n")
            schedule_decay(room_id, corpse_instance_id, 3)

          3 ->
            Enum.each(contents(corpse), &Room.add_item(room_id, &1))
            Room.remove_item(room_id, corpse_instance_id)
            tell_room(room_id, "一阵风吹过，把#{old_name}化成骨灰吹散了。\n")
        end

      :error ->
        # 尸体已被取走/房间重启：后续段自然终止
        :ok
    end
  end

  defp decayed(instance, phase) do
    item = Map.get(instance, :item)

    {name, description, aliases} =
      case phase do
        1 ->
          {"腐烂的尸体",
           "这具尸体显然已经躺在这里有一段时间了，正散发著一股腐尸的味道。",
           ["corpse", "尸体", "尸首", "腐烂的尸体"]}

        _ ->
          {"枯乾的骸骨", "这副骸骨已经躺在这里很久了。",
           ["skeleton", "骸骨", "枯乾的骸骨"]}
      end

    case item do
      %{meta: meta} when is_map(meta) ->
        new_meta =
          meta
          |> Map.put(:decay_phase, phase)
          |> Map.put(:aliases, aliases)

        %{instance | item: %{item | name: name, description: description, meta: new_meta}}

      _ ->
        instance
    end
  end

  defp corpse_name(%{item: %{name: name}}) when is_binary(name), do: name
  defp corpse_name(_), do: "尸体"

  defp tell_room(room_id, text) do
    try do
      Room.tell_room(%Room{id: room_id}, text)
    rescue
      _ -> :ok
    end
  end

  # ---- 狩猎掉落通知（跨进程，判定在击杀者侧做） ----

  defp notify_hunting_drops(character, killer) do
    drops = Hunting.drops_from_meta(Map.get(character, :meta, %{}) || %{})

    case {drops, killer_pid(killer)} do
      {%{} = drops, pid} when is_pid(pid) ->
        send(
          pid,
          %Event{
            from_pid: self(),
            topic: "hunting/drops",
            data: %{drops: drops, victim_name: Map.get(character, :name, "猎物")}
          }
        )

        :ok

      _ ->
        :ok
    end
  end

  defp killer_pid(%{pid: pid}) when is_pid(pid), do: pid
  defp killer_pid(%{"pid" => pid}) when is_pid(pid), do: pid
  defp killer_pid(_), do: nil

  # ---- 死者背包转移 ----

  defp inventory_of(character) do
    character
    |> Map.get(:inventory, [])
    |> List.wrap()
    |> Enum.filter(&match?(%Instance{}, &1))
  end

  # 幽灵态死亡（LPC chard.c 的 is_ghost() 分支）：不生成尸体，物品散落地面。
  defp drop_inventory_to_room(character, room_id) do
    character
    |> inventory_of()
    |> Enum.each(&Room.add_item(room_id, &1))
  end

  # ---- LPC 门控 ----

  defp wizard?(character) do
    env = Map.get(Map.get(character, :meta, %{}) || %{}, :env, %{}) || %{}

    Map.get(character, :wiz_level, 0) not in [nil, 0, ""] or
      Map.get(env, "wizard") == true or Map.get(env, :wizard) == true or
      safe_wizardp(character)
  end

  defp safe_wizardp(character) do
    Kantele.Admin.Access.wizardp(character)
  rescue
    _ -> false
  end

  defp ghost?(character) do
    meta = Map.get(character, :meta, %{}) || %{}
    damage = Map.get(meta, :damage, %{}) || %{}
    env = Map.get(meta, :env, %{}) || %{}

    Map.get(damage, :ghost) == true or Map.get(damage, "ghost") == true or
      Map.get(env, :ghost) == true or Map.get(env, "ghost") == true
  end

  # ---- 物品缓存查询 ----

  defp resolve_corpse_key do
    case resolve_drop_item(@corpse_key) do
      {key, _item} -> key
      nil -> "clone_lib:" <> @corpse_key
    end
  end

  defp fetch_item_pair(item_id) do
    try do
      case Items.get(item_id) do
        {:ok, item_def} -> {item_id, item_def}
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  # 兜底：掉落物定义可能在其他区（非 clone_lib），按 ":<短名>" 后缀找一次。
  defp find_item_by_suffix(short) do
    try do
      Items.keys()
      |> Enum.find(fn key -> is_binary(key) and String.ends_with?(key, ":" <> short) end)
      |> case do
        nil -> nil
        key -> fetch_item_pair(key)
      end
    rescue
      _ -> nil
    end
  end
end

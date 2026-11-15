defmodule Kantele.World.InteractionHints do
  @moduledoc """
  汇总「当前房间里能做什么」——按房间 / NPC / 地上物品三类，
  列出玩家**真的可以输入**的交互命令。

  数据源全部是房间进程里现成的加载结果：

  | 对象 | 字段 | 命令 |
  |---|---|---|
  | 房间 | `item_desc` 关键词 | `look <关键词>` |
  | 房间 | `actions` (`verb => handler`) | `<verb>` |
  | NPC  | `meta.ask_topics` / `meta.ask_handler` | `ask <名字> <关键词>` |
  | NPC  | `meta.init.add_actions` | `<verb>` |
  | 物品 | `item.verbs`（匹配 room 位置） | `<verb> <物品名>` |
  | 物品 | `item.meta.actions` (`verb`/`handler`) | `<verb> <物品名>` |

  ## 只列可执行动词

  UCL 里声明的 `add_action` 动词远多于真正移植过的 handler。若把数据原样
  列出来，玩家照着输入只会得到 "What?" 或被同名全局命令接住却什么也没发生。
  因此每条候选动词都要满足其一：

  - 对象级 handler 已注册（`RoomActionHandlers` / `NpcActionHandlers` /
    `ItemActionHandlers` 的 `registered?` / `lookup`）；
  - 或者它本身就是全局命令（`CommandVerbs.global?/1`）——例如 NPC 的
    `list` / `buy` 没有专属 handler，但确实走全局命令且能正常买卖。

  两类都不满足的动词（LPC 里尚未移植的 `do_*`）一律不展示。

  ## 两种粒度

  - `build/4` 默认 `limit: 6` 组，用于进入房间时自动追加的简短提示；
  - `limit: :none` 输出全部，用于显式的 `hints` 命令。
  """

  alias Kalevala.Verb
  alias Kalevala.Verb.Context, as: VerbContext
  alias Kantele.Character.CommandVerbs
  alias Kantele.World.ItemActionHandlers
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.RoomActionHandlers

  @default_limit 6
  # 自动提示每组最多几条命令。显式 `hints`（limit: :none）不截断。
  # 5 条刚好容纳：1 个 ask 示例 + 2 个对象动词 + talk + give。
  @per_group_limit 5

  @type group :: %{label: String.t(), commands: [String.t()]}

  @doc """
  汇总交互命令，返回按「房间 → NPC → 物品」排序的分组列表。

  选项：
  - `:limit`  最多返回几组，`:none` 表示不限（默认 #{@default_limit}）
  """
  def build(room, characters, item_instances, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    per_group = if limit == :none, do: :none, else: @per_group_limit

    groups =
      [room_group(room, per_group)] ++
        npc_groups(room, characters, per_group) ++ item_groups(item_instances, per_group)
      |> Enum.reject(&is_nil/1)

    case limit do
      :none -> groups
      n when is_integer(n) and n > 0 -> Enum.take(groups, n)
      _ -> groups
    end
  end

  @doc "把分组渲染成可直接输出给玩家的文本行"
  def lines(groups, opts \\ []) do
    full? = Keyword.get(opts, :full, false)

    header =
      if full?,
        do: "【当前房间可交互命令】",
        else: "【可交互 · 输入 hints 看全部】"

    footer =
      if full?,
        do: ["  （输入方向名移动；option hints_hidden 1 可关闭进入房间时的自动提示）"],
        else: ["  （option hints_hidden 1 可关闭本提示）"]

    body =
      Enum.map(groups, fn group ->
        "  #{group.label}：#{Enum.join(group.commands, "、")}"
      end)

    case body do
      [] -> []
      _ -> [header | body] ++ footer
    end
  end

  # ---------------------------------------------------------------- 房间

  defp room_group(%{item_desc: item_desc, actions: actions} = room, per_group) do
    look_commands =
      (item_desc || %{})
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(&"look #{&1}")

    action_commands =
      (actions || %{})
      |> Enum.filter(fn {verb, handler} ->
        RoomActionHandlers.registered?(room_id(room), handler) or CommandVerbs.global?(verb)
      end)
      |> Enum.map(fn {verb, _handler} -> verb end)
      |> Enum.sort()

    commands =
      (look_commands ++ action_commands)
      |> Enum.uniq()
      |> take_commands(per_group)

    group("房间", commands)
  end

  defp room_group(_room, _per_group), do: nil

  # ---------------------------------------------------------------- NPC

  defp npc_groups(room, characters, per_group) do
    (characters || [])
    |> Enum.reject(&player?/1)
    |> Enum.map(&npc_group(room, &1, per_group))
    |> Enum.reject(&is_nil/1)
  end

  defp npc_group(room, npc, per_group) do
    meta = Map.get(npc, :meta, %{}) || %{}
    name = npc_name(npc)

    ask_commands = ask_commands(meta, name, per_group)
    action_commands = npc_action_commands(room, meta, per_group)

    # `talk <NPC>` 只对配了问答资源的 NPC 有实质反应（见 TalkCommand 的
    # accept_talk 门控），其它 NPC 会回「X似乎不想和你聊天。」，不列以免误导。
    conversational? = ask_commands != []

    generic =
      ["talk", "give"]
      |> Enum.filter(fn
        "talk" -> conversational? and CommandVerbs.global?("talk")
        other -> CommandVerbs.global?(other)
      end)
      |> Enum.map(fn
        "give" -> "give <物品> to #{name}"
        verb -> "#{verb} #{name}"
      end)

    commands =
      (ask_commands ++ action_commands ++ generic)
      |> Enum.uniq()
      |> take_commands(per_group)

    group(name, commands)
  end

  # 自动版只给 1 个问询示例，给 talk/give 留出位置；完整版给全部关键词。
  defp ask_commands(meta, name, per_group) do
    topics = Map.get(meta, :ask_topics, []) || []

    cond do
      topics != [] ->
        topics
        |> take_commands(if per_group == :none, do: :none, else: 1)
        |> Enum.map(&"ask #{name} #{&1}")

      Map.get(meta, :ask_handler) != nil ->
        # AskHandler 的关键词写在模块里、UCL 没有 inquiries：给通用形式
        ["ask #{name} <关键词>"]

      true ->
        []
    end
  end

  defp npc_action_commands(room, meta, per_group) do
    init = Map.get(meta, :init, %{}) || %{}
    actions = Map.get(init, :add_actions, []) || []

    actions
    |> Enum.filter(fn verb ->
      NpcActionHandlers.registered?(room_id(room), verb) or CommandVerbs.global?(verb)
    end)
    |> take_commands(if per_group == :none, do: :none, else: 2)
  end

  # ---------------------------------------------------------------- 物品

  defp item_groups(item_instances, per_group) do
    (item_instances || [])
    |> Enum.filter(fn instance ->
      # 只保留「已加载」的实物。`ItemNotLoaded`（物品详情尚未从缓存取出）
      # 没有 verbs 字段，若漏进来会让下面的 `instance.item.verbs` 抛 KeyError；
      # 这里显式排除，与下面的 nil/非 Verb 兜底共同保证房间进程不崩。
      is_struct(instance.item, Kalevala.World.Item) and
        not is_struct(instance.item, Kalevala.World.Item.ItemNotLoaded)
    end)
    |> Enum.group_by(fn instance -> instance.item.name end)
    |> Enum.map(fn {name, instances} -> item_group(name, instances, per_group) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.label)
  end

  defp item_group(name, instances, per_group) do
    verb_commands =
      instances
      |> Enum.flat_map(fn instance ->
        (instance.item.verbs || [])
        # 防御：地上物品实例的 verbs 列表里可能混进 nil 或非 Verb 结构
        # （物品加载/转换的边界情况），直接传给 Kalevala.Verb.matches? 会触发
        # nil.conditions() 并让整个房间 GenServer 崩溃（见 room.ex LookEvent）。
        |> Enum.reject(fn verb -> is_nil(verb) or not is_struct(verb, Kalevala.Verb) end)
        |> Enum.filter(&Verb.matches?(&1, %VerbContext{location: "room"}))
        |> Enum.map(&to_string(Map.get(&1, :key)))
        |> Enum.filter(&CommandVerbs.global?/1)
      end)

    action_commands =
      instances
      |> Enum.flat_map(fn instance ->
        item_meta = instance.item.meta || %{}
        actions = Map.get(item_meta, :actions, []) || []

        actions
        |> Enum.filter(&item_action_registered?/1)
        |> Enum.map(&Map.get(&1, :verb))
      end)

    # 这里收集的是**动词**，统一拼上物品名生成可直接输入的命令。
    # 不补 `look <物品>`：`look <参数>` 走 `room/item_desc`（只认房间墙上的
    # 器物关键词），输入地上物品名会回「这里没有这个东西。」，属误导。
    # 没有任何可执行动词的物品不出现在提示里。
    commands =
      (verb_commands ++ action_commands)
      |> Enum.uniq()
      |> take_commands(per_group)
      |> Enum.map(&"#{&1} #{name}")

    group(name, commands)
  end

  defp item_action_registered?(%{handler: handler}) when is_binary(handler) do
    match?({:ok, _}, ItemActionHandlers.lookup(handler))
  end

  defp item_action_registered?(_), do: false

  # ---------------------------------------------------------------- 工具

  defp take_commands(list, :none), do: list
  defp take_commands(list, n) when is_integer(n), do: Enum.take(list, n)
  defp take_commands(list, _), do: list

  defp group(_label, []), do: nil
  defp group(label, commands), do: %{label: label, commands: commands}

  defp room_id(%{id: id}) when is_binary(id), do: id
  defp room_id(_), do: ""

  # Meta.trim 会把 struct 拍成普通 map，不能用 %PlayerMeta{} 匹配；
  # 玩家 id 恒为 "player:" 前缀（见 Kantele.World.Corpse.player?/1）。
  defp player?(%{id: id}) when is_binary(id), do: String.starts_with?(id, "player:")
  defp player?(_), do: false

  defp npc_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp npc_name(_), do: "某人"
end

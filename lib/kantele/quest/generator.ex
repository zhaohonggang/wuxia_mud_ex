defmodule Kantele.Quest.Generator do
  @moduledoc """
  开放任务模板生成器（Q1-T3，对应 LPC daemons/questd.c `start_all_quest` 的模板层）

  - `generate/2` 按类型分派到 `Deliver` / `Supply` / `Search` / `Explore` 子模块；
  - 世界数据的摘取放本模块（同 zone 随机落点 / 可上任委员 NPC / 随机物品），
    子模块只做各自的模板参数化；
  - 任一候选取不到时返回 `{:error, :no_candidates}`，由 QuestDaemon 跳过本轮补货。

  生成结果统一为：

      %{id: "qd-deliver-...", type: "deliver", level: 1..3, limit: 1800,
        officer_npc: "liuxi:erban", target_room: "liuxi:shantou",
        item_id: "liuxi:yupai", item_name: "血玉牌", count: 1,
        rewards: %{exp: n, potential: n, score: n, coins: n}, prompt: "..."}

  - `id` 即任务 spec 的 `file`（保证唯一），玩家 todo 里即此 id；
  - `officer_npc` 是发布与交付的同一 NPC（v1 单委派点；LPC 的 NPC1/NPC2 拆分留后续，
    见 §15 Q1-T3 风险）；
  - `target_room` 为同 zone 随机落点（提示用；入位校验待 Q2-T0 房间查询落地后接）。
  """

  alias Kantele.World.Items
  alias Kantele.World.ZoneCache

  @kind_deliver "deliver"
  @kind_supply "supply"
  @kind_search "search"
  @kind_explore "explore"
  @default_limit 1800

  @doc "按类型分派到子模块；未知类型返回 `{:error, :unknown_type}`"
  def generate(@kind_deliver, opts), do: Kantele.Quest.Generator.Deliver.generate(opts)
  def generate(@kind_supply, opts), do: Kantele.Quest.Generator.Supply.generate(opts)
  def generate(@kind_search, opts), do: Kantele.Quest.Generator.Search.generate(opts)
  def generate(@kind_explore, opts), do: Kantele.Quest.Generator.Explore.generate(opts)
  def generate(_kind, _opts), do: {:error, :unknown_type}

  def generate(kind), do: generate(kind, [])

  @doc "候选值包装：nil 转 `{:error, reason}`（配合 with 使用）"
  def ok_or_error(value, reason \\ :no_candidates)
  def ok_or_error(nil, reason), do: {:error, reason}
  def ok_or_error(value, _reason), do: {:ok, value}

  @doc "唯一任务 id（即 spec.file）"
  def gen_id(kind) do
    "qd-#{kind}-#{:erlang.system_time(:millisecond)}-#{rand_between(1000, 9999)}"
  end

  @doc "随机难度 1..3"
  def default_level(), do: rand_between(1, 3)

  @doc "缺省时限（秒）"
  def default_limit(), do: @default_limit

  @doc "随机整数 [min, max]"
  def rand_between(min, max) when is_integer(min) and is_integer(max) and min <= max do
    min + :rand.uniform(max - min + 1) - 1
  end

  # ---- 世界数据摘取（真实缓存，空则 :none；opts 可覆盖 zone/item 保证测试确定性）----

  @doc "已加载 zone id 列表（拍平排序，便于可复现）"
  def zone_ids(), do: ZoneCache.keys() |> Enum.sort()

  @doc "随机一个已加载 zone；`opts[:zone_id]` 指定时用指定 zone；无则 `:none`"
  def random_zone(opts \\ []) do
    case opts[:zone_id] do
      nil ->
        case zone_ids() do
          [] -> :none
          ids -> {:ok, ZoneCache.get!(Enum.random(ids))}
        end

      zone_id ->
        if zone_id in zone_ids() do
          {:ok, ZoneCache.get!(zone_id)}
        else
          :none
        end
    end
  end

  @doc """
  zone 内可作为开放任务委员的 NPC（拥有静态任务/交付配置的不占委员位）

  真实世界缓存中 zone.characters 是 `%{key => char}` 映射（loader 以键值对压入），
  先拍平成结构体列表再筛选。全部被静态配置占用的 zone 回退到「无 quest 配置的任意 NPC」。
  """
  def officer_candidates(zone) do
    chars = normalize_entries(zone.characters)

    case Enum.filter(chars, &free_officer?/1) do
      [] -> Enum.filter(chars, &(Map.get(&1.meta, :quest) == nil))
      free -> free
    end
  end

  def random_officer(zone) do
    case officer_candidates(zone) do
      [] -> nil
      list -> Enum.random(list)
    end
  end

  @doc "zone 内随机房间（有 id）；无则 nil"
  def random_room(zone) do
    case Enum.filter(zone.rooms |> normalize_entries(), &(Map.get(&1, :id) != nil)) do
      [] -> nil
      list -> Enum.random(list)
    end
  end

  @doc "随机可交付物品 `{item_id, item_name}`；`opts[:item_id]` 指定时用指定物品；物品名缺失时给兜底名"
  def random_item(opts \\ []) do
    case opts[:item_id] do
      nil ->
        case Items.keys() do
          [] -> nil
          keys -> random_item(Enum.random(keys))
        end

      item_id ->
        random_item_by_id(item_id)
    end
  end

  defp random_item_by_id(item_id) do
    case Items.get(item_id) do
      {:ok, %{name: name}} when is_binary(name) and name != "" -> {item_id, name}
      {:ok, _} -> {item_id, "一件货物"}
      _ -> nil
    end
  end

  defp free_officer?(%{meta: meta}) do
    Map.get(meta, :quest) == nil and Map.get(meta, :turn_in) == nil
  end

  defp free_officer?(_), do: false

  # 拍平映射型集合为值列表；列表则原样返回（测试/种子常用列表，loader 产出映射）
  defp normalize_entries(collection) when is_map(collection), do: Map.values(collection)
  defp normalize_entries(collection), do: collection
end
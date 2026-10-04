defmodule Kantele.World.Items do
  @moduledoc false

  use Kalevala.Cache
end

defmodule Kantele.World.Item do
  @moduledoc """
  Local callbacks for `Kalevala.World.Item`
  """

  use Kalevala.World.Item

  @doc """
  取物品定义；**缺失时不抛异常**，返回一个占位物品。

  `Kalevala.Cache` 的 `get!/1` 在 key 不存在时 `raise`，而物品实例是**持久化在
  数据库里**的 —— 只要世界数据里少了一个定义（转换器漏了某个区、某个区被删掉、
  物品 id 改名），登录时 `inventory/list` 就会把整个 Foreman  GenServer 带走：

      ** (RuntimeError) Could not find key global:potion in cache Elixir.Kantele.World.Items
          (ex_venture 0.1.0) lib/kantele/character/events/inventory_event.ex:10
          (kalevala 0.1.0) lib/kalevala/character/foreman.ex:105

  玩家的背包里有一件"查不到定义"的物品，不该导致角色无法登录。
  占位物品带原 id，界面上显示为「未知物品」，问题依然可见但不再致命。
  """
  # 注意必须写全名 `Kantele.World.Items`：本文件里 `Kantele.World.Item` 与
  # `Kantele.World.Items` 是兄弟模块，写裸 `Items` 在这个模块里被解析成
  # `Elixir.Items`，运行时报 "module Items is not available"。
  def fetch(item_id) do
    case Kantele.World.Items.get(item_id) do
      {:ok, item} -> item
      {:error, :not_found} -> missing_item(item_id)
    end
  end

  @doc """
  填好 `item_instance.item`；定义缺失时填占位物品而不是崩掉。
  """
  def resolve(%{item_id: item_id} = item_instance) do
    %{item_instance | item: fetch(item_id)}
  end

  def missing_item(item_id) do
    %Kalevala.World.Item{
      id: item_id,
      name: "未知物品（#{item_id}）",
      description: "这件物品的定义不在世界数据里。",
      meta: %{}
    }
  end

  @doc """
  物品名匹配：全名精确或按第一个词前缀匹配

  双语名（如 "长剑 Changjian"）允许玩家只输入中文名 "长剑"
  """
  def matches?(item, keyword) do
    keyword = String.downcase(String.trim(keyword))
    name = String.downcase(item.name)

    name == keyword or String.starts_with?(name, "#{keyword} ")
  end

  @doc """
  创建坐骑模板（供 horseboss 调用）
  """
  def create_mount(attrs) do
    %Kalevala.World.Item{
      id: attrs.id,
      name: attrs.name,
      description: attrs.description,
      meta: %{
        "type" => "mount",
        "species" => attrs.species,
        "gender" => attrs.gender,
        "unit" => attrs.unit,
        "stats" => attrs.stats,
        "owner" => attrs.owner,
        "owner_name" => attrs.owner_name,
        "summon_id" => attrs.summon_id,
        "rideable" => true,
        "trained" => true
      }
    }
  end

  @doc "给予玩家坐骑实例"
  def give_mount(player, mount_template) do
    instance = %Kalevala.World.Item.Instance{
      id: Instance.generate_id(),
      item_id: mount_template.id,
      created_at: DateTime.utc_now(),
      item: mount_template
    }

    %{player | inventory: [instance | player.inventory]}
  end

  @doc "检查物品模板 ID 是否已存在"
  def item_exists?(id) do
    case Kantele.World.Items.get(id) do
      {:ok, _item} -> true
      _ -> false
    end
  end
end

defmodule Kantele.World.Item.Meta.Book do
  @moduledoc """
  秘籍类物品的可研习信息（对应 LPC 秘籍的 skill mapping，裁剪自 study 流程）

  - `skill` 可研习的技能 id（如 "literate"）
  - `min_skill` / `max_skill` 有效研习区间，低于/超出均无收获（study.c）
  - `exp_required` 实战经验门槛（combat_exp）
  - `jing_cost` 每次研习的精力消耗
  - `difficulty` 难度基准（LPC 用于消耗公式 `(jing_cost*20 + difficulty - int)/20`）

  本期只解析存储；消费端（研习命令/耗精公式）由 b 期 learn 重构接入。
  """

  defstruct [:skill, :min_skill, :max_skill, :exp_required, :jing_cost, :difficulty]
end

defmodule Kantele.World.Item.Meta do
  @moduledoc """
  Item metadata, implements `Kalevala.Meta`

  战斗相关扩展字段（由世界数据 `meta = {}` 块解析）：

  - `damage` 武器伤害值（对应 LPC init_sword/1）
  - `skill_type` 武器技能类型，如 "sword"（对应 query skill_type）
  - `armor` 护甲值（对应 LPC armor_prop/armor）
  - `value` 价值

  装备多槽位扩展（b6/D3+B4，对应 LPC equip.c armor_type 与 weapon_prop/armor_prop）：

  - `armor_type` 槽位名（cloth/head/feet/waist/hands/neck/cloak/finger；body 归一化为 cloth）
  - `weapon_prop` 多键武器加成（仅 @applies_keys 白名单键，如 `%{attack: 3}`）
  - `armor_prop` 多键护甲加成（同上，如 `%{defense: 4, dodge: 2}`）

  通用/消耗品类扩展字段（A4/D1，对应 LPC set_weight/unit/material 等）：

  - `weight` 重量（整数，LPC 单位为克）
  - `unit` 量词（如 "个"、"本"，用于文案展示）
  - `material` 材质（如 "silk"、"bone"）
  - `food` 饱食度供给（对应 LPC food_supply；饥饿系统消费端属 O4）
  - `medicine` 药效 map（原样透传，如 `%{qi: 50, stats: %{str: 1}}`；消费端见 A7）
  - `book` 秘籍五元组 `%Meta.Book{}`（消费端研习命令属 b 期）
  - `flag` 武器类型位掩码（LPC weapon.h：ONE_HANDED=0x1, SECONDARY=0x2, TWO_HANDED=0x4；缺省 0x1 单手）

  背包扩展字段（Backpack 宿主接线，对应 `feature/user_storage.c`）：

  - `storage_bag` 存储扩展格数（整数；为 nil 表示非背包容器）

  任务物品扩展字段（Q5 宝镜任务，对应 LPC set_task 物品 meta）：

  - `no_sell` 不可出售（Seller/Dealer 拒绝语；非空即拦截）
  - `no_put` 不可存入容器（backpack/item 命令展示拒绝语）
  - `owner` 物主姓名（触发上交的 NPC 匹配名前缀，如 "清法比丘"）
  - `owner_id` 物主 id（上交匹配优先键，如 "qingfa biqiu"）
  """

  defstruct [
    :damage,
    :skill_type,
    :armor,
    :value,
    :weight,
    :unit,
    :material,
    :food,
    :medicine,
    :book,
    :armor_type,
    :weapon_prop,
    :armor_prop,
    :flag,
    :storage_bag,

    # LPC `set_name(<名>, ({ "id1", "id2" }))` 的 id 表（对应 present/get 的匹配依据）。
    # 转换早期整组丢失，导致 `present('mian')` 这类拼音 id 匹配不上，
    # 由 scripts/migrate_aliases.py 从源 .c 回填。
    {:aliases, []},

    # 任务物品扩展（Q5 宝镜任务，对应 LPC set_task 物品的 meta 字段）
    :no_sell,
    :no_put,
    :owner,
    :owner_id
  ]

  @doc """
  归一化 armor_type：body→cloth 别名；白名单外/非字符串返回 nil
  """
  def normalize_armor_type(nil), do: nil

  def normalize_armor_type(type) when is_binary(type) do
    type = type |> String.downcase() |> String.trim()
    type = if type == "body", do: "cloth", else: type

    if type in Kantele.Character.Combat.armor_slots(), do: type
  end

  def normalize_armor_type(_), do: nil

  @doc """
  prop 白名单过滤：仅保留 applies_keys 内且值为整数的键；空表返回 nil

  LPC prop 表可含技能类加成（sword+5 等），需 Fighter.skills 通道，
  v0 不支持——白名单外的键丢弃。
  """
  def sanitize_prop(nil), do: nil

  def sanitize_prop(prop) when is_map(prop) do
    allowed = Kantele.Character.Combat.applies_keys()

    filtered =
      Enum.reduce(prop, %{}, fn {key, value}, acc ->
        atom_key =
          cond do
            is_atom(key) -> key
            is_binary(key) -> String.to_atom(key)
            true -> nil
          end

        if atom_key in allowed and is_integer(value) do
          Map.put(acc, atom_key, value)
        else
          acc
        end
      end)

    if filtered == %{}, do: nil, else: filtered
  end

  def sanitize_prop(_), do: nil

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:damage, :armor])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

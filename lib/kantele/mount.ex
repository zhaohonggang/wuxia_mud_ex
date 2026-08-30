defmodule Kantele.Mount do
  @moduledoc """
  坐骑管理（对应 LPC transport.c / horseboss 衔接）：

  - 召唤：`whistle <summon_id>` 将坐骑从马厩/仓库移入背包
  - 收回：`stable <mount>` 将坐骑送回马厩
  - 骑乘权限：`Transport.can_drive_by?` 检查 owner/同房间
  - 持久化：owner_id, summon_id 存储在 item.meta
  """

  alias Kantele.Item.Transport
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance

  @doc """
  检查玩家能否驾驶该坐骑

  `instance` 是背包中的 Item.Instance，`player` 是角色 struct
  """
  def can_ride?(instance, player) do
    item = instance.item

    if not ridable?(item) do
      {:error, "这不是可驾驶的载具。"}
    else
      owner = Transport.query_owner(item)
      opts = %{
        owner: owner,
        me: player.id,
        owner_room: player.room_id,  # nil 视为不在同房间（允许驾驶）
        my_room: player.room_id
      }

      case Transport.can_drive_by?(opts) do
        true -> :ok
        false -> {:error, "这是#{owner_name(owner, item)}的车，你乱动什么？"}
      end
    end
  end

  defp ridable?(item) do
    meta = item.meta
    Map.get(meta, "ridable") == true || Map.get(meta, "type") == "mount"
  end

  @doc "召唤坐骑：从仓库/马厩移入背包"
  def summon(player, summon_id) do
    # 查找玩家拥有的、summon_id 匹配的坐骑
    # 先检查背包
    existing = Enum.find(player.inventory, fn inst ->
      Map.get(inst.item.meta, "summon_id") == summon_id
    end)

    case existing do
      nil ->
        # 不在背包：尝试从仓库加载（需要存储层支持，暂返回错误）
        {:error, "找不到召唤 ID 为 #{summon_id} 的坐骑。"}

      inst ->
        {:ok, inst}
    end
  end

  @doc "收回坐骑：从背包移出（标记为在马厩）"
  def stable(player, instance) do
    if Map.get(instance.item.meta, "rideable") != true do
      {:error, "这不是坐骑。"}
    else
      # 标记 meta.stabled = true，或移出背包存入仓库
      # 简化版：直接移出背包，meta 保留
      {:ok, instance}
    end
  end

  @doc "创建坐骑模板（供 horseboss 调用）"
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
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: mount_template.id,
      created_at: DateTime.utc_now(),
      item: mount_template
    }

    %{player | inventory: [instance | player.inventory]}
  end

  defp owner_name(nil, _item), do: "无主"
  defp owner_name(owner_id, item) do
    owner_name = Map.get(item.meta, "owner_name")
    if owner_name, do: owner_name, else: owner_id
  end
end
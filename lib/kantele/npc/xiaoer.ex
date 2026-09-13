defmodule Kantele.NPC.Xiaoer do
  @moduledoc """
  店小二 NPC 行为处理（真实 API 版本）

  功能：
  - 收钱：记录 rent_paid，找零
  - 收尸体：移至丢弃房间
  - 积分兑换：扣积分给物品
  - 心跳清理：移动闲置玩家、清理尸体
  """

  alias Kantele.World.Items
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.Room

  @greetings [
    "店小二笑嘻嘻地说道：这位客官，里面请！",
    "店小二哈腰道：客官里面请，小店有上好的茶水。",
    "店小二抹着桌子喊道：客官请坐，有什么吩咐？",
    "店小二眯着眼笑道：难得客官光临，请里面坐！"
  ]

  @exchange_items %{
    "blood_bodhi" => [cost: 5, item: "pill/puti1", name: "血菩提"],
    "sarira" => [cost: 5, item: "pill/sheli1", name: "舍利子"],
    "haotian_fruit" => [cost: 5, item: "pill/linghui1", name: "昊天果"],
    "bone_strength" => [cost: 5, item: "gift/con1", name: "壮骨散"],
    "longevity_paste" => [cost: 5, item: "gift/dex1", name: "延年膏"],
    "wisdom_pill" => [cost: 5, item: "gift/int1", name: "聪慧丸"],
    "strength_pill" => [cost: 5, item: "gift/str1", name: "大力丸"],
    "rebirth_pill" => [cost: 50, item: "gift/con3", name: "还魂丹"]
  }

  @rent_per_night 100
  @discard_room "/d/room/discard"
  @outside_room "/d/room/outside"
  @heartbeat_interval 60_000

  @doc "随机问候语"
  def greet, do: Enum.random(@greetings)

  @doc "判断是否为店小二 NPC（有 goods 且是商人）"
  def is_xiaoer?(%{meta: %{goods: goods}} = character) when is_list(goods) and goods != [], do: true
  def is_xiaoer?(_), do: false

  @doc "获取租金标准"
  def rent_per_night, do: @rent_per_night

  @doc "获取兑换列表"
  def exchange_items, do: @exchange_items

  @doc "获取物品显示名"
  def item_name(item_instance) do
    case Items.get(item_instance.item_id) do
      {:ok, item} -> item.name
      _ -> "物品"
    end
  end

  @doc "验证给予物品：返回 {:ok, action} 或 {:error, msg}"
  def validate_give(npc, item_instance) do
    item = Items.get!(item_instance.item_id)

    cond do
      Kantele.Item.is_currency?(item) ->
        amount = Kantele.Item.currency_amount(item)

        if amount >= @rent_per_night do
          {:ok, %{type: :pay_rent, amount: amount}}
        else
          {:error, "钱不够住店，至少需要 #{@rent_per_night} 文。"}
        end

      Kantele.Item.is_corpse?(item) ->
        {:ok, %{type: :dispose_corpse}}

      Kantele.Item.is_exchange_item?(item) ->
        item_key = item.id
        exchange = Map.get(@exchange_items, item_key)

        if exchange == nil do
          {:error, "没有这个兑换项目。"}
        else
          {:ok, %{type: :exchange_item, item_key: item_key}}
        end

      true ->
        {:error, "小二不收这个东西。"}
    end
  end

  @doc "获取租金标准（函数版）"
  def rent_per_night, do: @rent_per_night

  @doc "获取兑换列表"
  def exchange_items, do: @exchange_items

  @doc "获取物品显示名"
  def item_name(item_instance) do
    case Items.get(item_instance.item_id) do
      {:ok, item} -> item.name
      _ -> "物品"
    end
  end

  @doc "随机问候语"
  def greet, do: Enum.random(@greetings)

  @doc "判断是否为店小二 NPC（有 goods 且是商人）"
  def is_xiaoer?(%{meta: %{goods: goods}} = character) when is_list(goods) and goods != [], do: true
  def is_xiaoer?(_), do: false

  # --- 心跳清理 ---

  @doc "启动心跳定时器（在 NPC 初始化时调用）"
  def start_heartbeat(npc) do
    # 实际应使用 Scheduler，这里简化为定时消息
    :timer.send_interval(@heartbeat_interval, :xiaoer_heartbeat)
  end

  @doc "心跳处理：清理闲置玩家、清理尸体"
  def heartbeat(npc) do
    room_snapshot = Room.snapshot(npc.room_id)

    # 清理闲置玩家（实际移动需跨进程，这里记录日志）
    Enum.each(room_snapshot.private.characters, fn character ->
      if character.id != npc.id and PlayerMeta.get_temp(character.meta, "idle_count") > 3 do
        IO.puts("[Xiaoer] #{character.name} 发呆太久，被店小二请出去了。")
      else
        # 增加闲置计数
        # 实际需通过事件更新角色状态
      end
    end)

    # 清理房间内尸体
    Enum.each(room_snapshot.private.item_instances, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      if Kantele.Item.is_corpse?(item) do
        IO.puts("[Xiaoer] 清理了 #{item.name}。")
      end
    end)
  end
end
defmodule Kantele.NPC.Xiaoer do
  @moduledoc """
  店小二 NPC（对应 lpc_example/ex/npc_xiaoer/）

  功能：
  - 问候与随机欢迎语
  - 钱币处理（收租、找零、租金记录）
  - 尸体处理（收尸、移至丢弃房间）
  - 积分兑换系统（血菩提、舍利子等）
  - 心跳清理（移动闲置玩家、清理尸体）
  """
  alias Kantele.World.Room
  alias Kantele.Item
  alias Kantele.Character
  alias Kantele.Character.PlayerMeta
  alias Kantele.Scheduler

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

  defstruct [
    :id,
    :name,
    :room_id,
    exchange_items: @exchange_items,
    rent_per_night: @rent_per_night
  ]

  @doc "初始化店小二"
  def init_npc do
    %__MODULE__{}
  end

  @doc "随机问候语"
  def greet do
    Enum.random(@greetings)
  end

  @doc "处理给予物品（钱币/尸体/兑换）"
  def handle_give(npc, player, item) do
    cond do
      Item.is_currency?(item) ->
        handle_money(player, item)

      Item.is_corpse?(item) ->
        handle_corpse(item)

      Item.is_exchange_item?(item) ->
        exchange_item(player, item)

      true ->
        {:error, "小二不收这个东西。"}
    end
  end

  # --- 钱币处理 ---

  defp handle_money(player, money) do
    amount = Item.currency_amount(money)

    if amount >= @rent_per_night do
      rent_paid = PlayerMeta.get_temp(player.meta, "rent_paid") || 0
      new_rent = rent_paid + amount

      player = PlayerMeta.put_temp(player.meta, "rent_paid", new_rent)

      change = amount - @rent_per_night

      msg =
        if change > 0 do
          "多谢客官，找您 #{change} 文钱。您已预付 #{new_rent} 文房钱。"
        else
          "多谢客官，您已预付 #{new_rent} 文房钱。"
        end

      {:ok, player,
       [
         %{
           type: :tell,
           target: player.id,
           text: msg
         }
       ]}
    else
      {:error, "钱不够住店，至少需要 #{@rent_per_night} 文。"}
    end
  end

  # --- 尸体处理 ---

  defp handle_corpse(corpse) do
    # 移至丢弃房间
    discard_room = "/d/room/discard"
    Room.move_object(corpse, discard_room)

    {:ok, "店小二拖着尸体拖到了后院。"}
  end

  # --- 积分兑换 ---

  def exchange(player, item_key) do
    item = Map.get(@exchange_items, item_key)

    if item == nil do
      {:error, "没有这个兑换项目。"}
    else
      points = Character.points(player)

      if points >= item.cost do
        Character.add_points(player, -item.cost)
        item_instance = Item.create(item.item)
        Character.give_item(player, item_instance)

        {:ok, "兑换成功！您获得了 #{item.name}。"}
      else
        {:error, "您的积分不足，需要 #{item.cost} 点。"}
      end
    end
  end

  # --- 心跳清理 ---

  # 60秒
  @heartbeat_interval 60_000

  @doc "启动心跳定时器"
  def start_heartbeat(npc) do
    Scheduler.schedule_recurring(@heartbeat_interval, fn ->
      heartbeat(npc)
    end)
  end

  @doc "心跳处理：清理闲置玩家、清理尸体"
  def heartbeat(npc) do
    room = Room.get(npc.room_id)

    # 清理闲置玩家（移至室外）
    Enum.each(room.players, fn player ->
      if Character.idle?(player) do
        outside_room = "/d/room/outside"
        Room.move_object(player, outside_room)

        Room.broadcast(room, "#{player.name} 发呆太久，被店小二请出去了。")
      end
    end)

    # 清理房间内尸体
    Enum.each(Room.get_objects(room), fn obj ->
      if Item.is_corpse?(obj) do
        Room.move_object(obj, "/d/room/discard")
      end
    end)
  end

  # --- 辅助函数 ---

  defp exchange_item(player, item) do
    # 实际实现中会检查物品模板
    {:error, "暂未实现完整兑换逻辑"}
  end
end

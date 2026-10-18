defmodule Kantele.World.NpcActions.Ride do
  @moduledoc """
  P5-1c-3 NPC 样板：`ride*` 十连（马童快速旅行，八卦门专属）。

  对应 LPC `d/beijing/npc/matong.c` 的 `do_ride*` 系列函数：
  - 检查玩家门派是否为“八卦门”，否则马童拉住玩家并喊“有人要偷马”，命令被消耗
  - 检查是否已骑乘（meta.temp.is_riding），若是则提示并放行（LPC return 0）
  - random(3) 抽马名：紫骝马 / 枣红马 / 黄骠马
  - 沿 front_yard → gate → di_anmen → 目的地马厩 逐房间 move 并广播
  - 落点“跃下马来”

  所有 10 个动词复用同一份参数化实现，仅目的地不同。
  """

  use Kantele.World.NpcAction

  alias Kantele.World.RoomActions.Helpers
  alias Kantele.Character.Family

  # 所有路线共用前缀：beijing 内三个房间
  @common_prefix ["beijing:front_yard", "beijing:gate", "beijing:di_anmen"]

  # 各动词的目的地路线（不含共用前缀）
  @destinations %{
    "rideyz" => ["city:kedian", "city:majiu"],
    "ridedl" => ["dali:dahejiewest", "dali:bingying", "dali:majiu"],
    "rideem" => ["emei:qsjie2", "emei:caopeng", "emei:majiu1"],
    "ridefs" => ["foshan:street4", "foshan:yingxionglou", "foshan:majiu"],
    "ridefz" => ["fuzhou:dongdajie", "fuzhou:rongcheng", "fuzhou:majiu"],
    "ridehz" => ["hangzhou:road13", "hangzhou:kedian", "hangzhou:majiu"],
    "ridesz" => ["suzhou:canlangting", "suzhou:beidajie1", "suzhou:majiu"],
    "ridexy" => ["xiangyang:dingzi", "xiangyang:northroad2", "xiangyang:majiu"],
    "rideyd" => ["huanghe:yongdeng", "huanghe:kedian", "huanghe:majiu"],
    "rideyl" => ["xiyu:shanjiao", "xiyu:beijiang", "xiyu:majiu"],
  }

  @impl true
  def run(conn, %{verb: verb, room_id: room_id, npc: _npc}) do
    cond do
      not is_binary(room_id) or room_id == "" ->
        :not_handled

      family_name(conn) != "八卦门" ->
        # 非八卦门：马童拉住玩家，喊“有人要偷马”，命令被消耗（LPC return 1）
        conn =
          Helpers.broadcast_vision(conn, room_id,
            "马童一把拉住$N，大声喊道：“快来人啊，有个无耻贼子要偷马！”")
        conn

      is_riding?(conn) ->
        # 已经有坐骑：提示并放行（LPC notify_fail + return 0）
        Helpers.render_to_player(conn,
          "你已经有坐骑了，自己直接rideto不就行了？")
        :not_handled

      true ->
        do_ride(conn, verb, room_id)
    end
  end

  defp do_ride(conn, verb, room_id) do
    destinations = Map.get(@destinations, verb, [])
    hname = pick_horse()

    # 出发：马童牵来马
    conn =
      Helpers.broadcast_vision(conn, room_id,
        "马童笑嘻嘻地牵来一匹#{hname}，对$N道：“快上马吧。”。")

    # 骑马离开当前房间
    conn =
      Helpers.broadcast_vision(conn, room_id,
        "只见$N骑着#{hname}穿过镖局扬长而去，踏起一路尘埃。")

    # 逐房间移动并播报
    all_rooms = @common_prefix ++ destinations
    conn =
      Enum.reduce(all_rooms, conn, fn next_room_id, conn ->
        conn = Helpers.move_to(conn, next_room_id)
        Helpers.broadcast_vision(conn, next_room_id,
          "$N骑着#{hname}一路招摇疾驰而过。")
      end)

    # 落下马来（仅当有目的地时）
    case destinations do
      [] ->
        conn

      [last_destination | _] ->
        Helpers.broadcast_vision(conn, last_destination,
          "$N身形一转，跃下马来，姿态十分优美。闲人也给$N一大哄！")
    end
  end

  defp pick_horse do
    case :rand.uniform(3) do
      1 -> "紫骝马"
      2 -> "枣红马"
      _ -> "黄骠马"
    end
  end

  defp family_name(conn) do
    family = Map.get(conn.character.meta, :family)
    Family.name(family)
  end

  defp is_riding?(conn) do
    temp = Map.get(conn.character.meta, :temp)
    Map.get(temp, :is_riding, false)
  end
end

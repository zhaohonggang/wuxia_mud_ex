defmodule Kantele.World.RoomActions.Banquet do
  @moduledoc """
  P5-9 #9 一次性场景：醉仙楼宴厅「承办酒席」`order` / `broadcast`。

  LPC 源：`d/city/furong.c`、`d/city/meigui.c`、`d/city/mudan.c`
  （三厅 `do_order` / `do_broadcast` 逻辑完全一致，仅「厅名」不同）。
  UCL 已就绪：三房 `actions = { order = "do_order", broadcast = "do_broadcast" }`
  —— **零 UCL 改动**。

  ## 移植范围（LPC 判定链）

  ### `do_order <type>`（`order` 动词）

  1. `arg == "end"` 且当前房 `order_owner == me` → 结束宴会：
     清房 state（等价 LPC `delete("order_owner"/"order_type")` + `destruct`
     房内非玩家物品），播「【江湖通告】<厅名>的宴会结束了。」。
  2. 已有 `order_owner`（且非本人 end）→ 「这里已经被人包租了。」（LPC
     `if (mesg) return notify_fail(...)`）。
  3. 无 owner，按 `type` 分支：
     - `birthday`：查 20000 / 付 20000，播「举行生辰寿宴」；
     - `marry`：查 30000 / 付 30000，播「举行订婚酒宴」；
     - `player`：查 50000 / 付 **40000**（LPC 原样：`can_afford(50000)` 但
       `pay_money(40000)`，忠实保留此不一致），播「宴请各路英雄豪杰」。
     - 其它 → 「你要定什么酒席?」。
  4. 钱不足（`meta.coins < check`）→ 「你没有足够的钱或零钱不够。」。
  5. 成功：`meta.coins -= pay`，房 state 记 `%{owner, type, items}`，
     播「【江湖通告】<玩家名>现在在<厅名><phrase>。」。

  ### `do_broadcast`（`broadcast` 动词）

  仅 `order_owner` 可再次公告；非主人给一句提示（LPC `return 0` 不接管，
  这里改为可读反馈）。

  ## 与 LPC 的差异 / 已知缺口

  - **`message("channel:chat", ...)`（全服 `users()` 江湖通告）** 沿用
    `hangzhou:loveroom` 的既有约定，用 `Helpers.broadcast_vision/3` 投给本房
    作为可观测反馈（语义近似，非逐字等价）。
  - **宴席物品入房暂未落地**：LPC `create_food/create_water/create_wine`
    用 `new(__DIR__"obj/food")` 等自定义类实例化后 `move(this_object())`；
    本引擎 `Room.move_object/2` 目前是**空实现**（`get_item_instances_in_room/1`
    恒 `[]`），且无 food/water/wine 物品原型。故本模块把每类宴席的酒水菜肴
    作为**数据**记入房 state `items`（faithful 内容，待 `move_object` 子系统
    落地即可生成实体），当前不发实体。
  - **`valid_leave` 未接线**：LPC 禁止主人在 `order end` 前离场（`valid_leave`
    返回 `notify_fail`）。本引擎移动路径尚未消费房 `valid_leave` 配置
    （@todo：移动命令侧加校验），故此处未拦截离场。
  - **`init()` 入房减半食物/水**：LPC 在 `order_owner` 存在时对进入者
    `food/water /= 2`；本引擎食物/水 vital 未建模，略过。
  """

  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @state_key "banquet"

  # 厅名（LPC 各文件硬编码文案）：hall = 公告用全称，short = 结束语用简称
  @halls %{
    "city:furong" => %{hall: "醉仙楼芙蓉厅", short: "芙蓉厅"},
    "city:meigui" => %{hall: "醉仙楼玫瑰厅", short: "玫瑰厅"},
    "city:mudan" => %{hall: "醉仙楼牡丹厅", short: "牡丹厅"}
  }

  # type => {查钱额, 实付额, 公告短语}
  @types %{
    "birthday" => {20_000, 20_000, "举行生辰寿宴"},
    "marry" => {30_000, 30_000, "举行订婚酒宴"},
    "player" => {50_000, 40_000, "宴请各路英雄豪杰"}
  }

  # 每类宴席的酒水菜肴（逐条取自 LPC create_water/create_wine/create_food）。
  # 形式：{:food, 名称, 别名} 或 {:water|:wine, 名称, 别名, 杯盏名}。
  @dishes %{
    "marry" => [
      {:water, "龙井茶", ["tea"], "紫砂茶盅"},
      {:water, "普洱茶", ["tea"], "水晶盏"},
      {:wine, "米酒", ["wine"], "搪瓷杯"},
      {:wine, "竹叶青", ["wine"], "翡翠杯"},
      {:wine, "绍兴黄酒", ["wine"], "象牙杯"},
      {:wine, "女儿红", ["wine"], "紫檀杯"},
      {:wine, "茅台酒", ["wine"], "鎏金杯"},
      {:wine, "桂花酒", ["wine"], "琉璃杯"},
      {:food, "香酥花生", ["peanut"]},
      {:food, "酒糟红枣", ["jujube"]},
      {:food, "喜糖", ["sugar"]},
      {:food, "奶油瓜子", ["melon seeds", "seeds"]},
      {:food, "碧螺春卷", ["spring roll", "roll"]},
      {:food, "香片蒸鱼", ["fish"]},
      {:food, "麻辣手撕鸡", ["chicken"]},
      {:food, "干煸尤鱼", ["fish"]},
      {:food, "东北水饺", ["dumpling"]},
      {:food, "麻辣火锅", ["chafing dish", "dish"]},
      {:food, "油煎螃蟹", ["crab"]},
      {:food, "粉蒸肉", ["meat"]},
      {:food, "家常豆腐", ["bean curd"]}
    ],
    "birthday" => [
      {:water, "云雾茶", ["tea"], "紫砂茶盅"},
      {:water, "君山银针", ["tea"], "红泥盏"},
      {:water, "鲜奶", ["milk"], "玻璃杯"},
      {:wine, "陈年花雕", ["wine"], "宋瓷杯"},
      {:wine, "五粮液", ["wine"], "玻璃杯"},
      {:wine, "米酒", ["wine"], "搪瓷杯"},
      {:wine, "杜康酒", ["wine"], "青铜爵"},
      {:wine, "透瓶香", ["wine"], "琉璃杯"},
      {:food, "德州扒鸡", ["chicken"]},
      {:food, "碧螺春卷", ["spring roll", "roll"]},
      {:food, "香片蒸鱼", ["fish"]},
      {:food, "咖喱饭", ["rice"]},
      {:food, "蚝油肉片", ["fish meat", "meat"]},
      {:food, "羊肉串", ["mutton"]},
      {:food, "重庆火锅", ["chafing dish", "dish"]},
      {:food, "北京烤鸭", ["duck"]},
      {:food, "粉蒸肉", ["meat"]},
      {:food, "四喜豆腐", ["bean curd"]}
    ],
    "player" => [
      {:water, "羊奶", ["milk"], "青花碗"},
      {:water, "云雾茶", ["tea"], "紫砂茶盅"},
      {:water, "碧螺春", ["tea"], "紫砂盏"},
      {:water, "君山银针", ["tea"], "红泥盏"},
      {:water, "红毛尖", ["tea"], "青泥盏"},
      {:wine, "汾酒", ["wine"], "羊脂白玉杯"},
      {:wine, "关外白酒", ["wine"], "犀角杯"},
      {:wine, "葡萄酒", ["wine"], "夜光杯"},
      {:wine, "高粱酒", ["wine"], "青铜爵"},
      {:wine, "百草酒", ["wine"], "古藤杯"},
      {:wine, "状元红", ["wine"], "古瓷杯"},
      {:wine, "梨花酒", ["wine"], "翡翠杯"},
      {:wine, "玉露酒", ["wine"], "琉璃杯"},
      {:food, "叫花鸡", ["chicken"]},
      {:food, "四喜豆腐", ["bean curd"]},
      {:food, "碧螺春卷", ["spring", "roll"]},
      {:food, "香片蒸鱼", ["fish"]},
      {:food, "羊肉串", ["mutton"]},
      {:food, "花枝饭卷", ["rice"]},
      {:food, "鱼香肉丝", ["fish meat", "meat"]},
      {:food, "德州扒鸡", ["chicken"]},
      {:food, "麻辣火锅", ["chrafing dish", "dish"]},
      {:food, "北京烤鸭", ["duck"]},
      {:food, "白斩鸡", ["chicken"]},
      {:food, "粉蒸肉", ["meat"]},
      {:food, "重庆火锅", ["chafing dish", "dish"]},
      {:food, "麻婆豆腐", ["bean curd"]},
      {:food, "蚝油肉片", ["fish meat", "meat"]},
      {:food, "咖喱饭", ["rice"]},
      {:food, "麻辣手撕鸡", ["chicken"]},
      {:food, "干煸尤鱼", ["fish"]},
      {:food, "东北水饺", ["dumpling"]}
    ]
  }

  @impl true
  # 无角色上下文（如 `%Conn{}`）不接管，交回分发器（同 City.Bet 的守卫）
  def run(%{character: nil}, _params), do: :not_handled

  def run(conn, %{room_id: room_id, verb: verb, trailing: trailing}) when is_binary(room_id) do
    if Map.has_key?(@halls, room_id) do
      case verb do
        "do_order" -> do_order(conn, room_id, to_string(trailing || ""))
        "do_broadcast" -> do_broadcast(conn, room_id)
        _ -> :not_handled
      end
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  # ---- order ----------------------------------------------------------------

  defp do_order(conn, room_id, arg) do
    arg = String.trim(arg)
    character = current(conn)
    owner = state_owner(room_id)

    cond do
      # LPC: if (mesg && arg=="end" && mesg==me->query("id")) → 结束
      arg == "end" and owner == character.id ->
        end_banquet(conn, room_id)

      # LPC: if (mesg) return notify_fail("这里已经被人包租了。\n");
      not is_nil(owner) ->
        Helpers.render_to_player(conn, "这里已经被人包租了。\n")

      true ->
        order(conn, room_id, character, arg)
    end
  end

  defp order(conn, room_id, character, arg) do
    case Map.fetch(@types, arg) do
      :error ->
        # LPC: return notify_fail("你要定什么酒席?\n");
        Helpers.render_to_player(conn, "你要定什么酒席?\n")

      {:ok, {check, pay, phrase}} ->
        coins = coins_of(character)

        if coins < check do
          # LPC: notify_fail("你没有足够的钱或零钱不够。\n");
          Helpers.render_to_player(conn, "你没有足够的钱或零钱不够。\n")
        else
          %{hall: hall} = Map.fetch!(@halls, room_id)

          Room.put_state_by_id(room_id, @state_key, %{
            owner: character.id,
            type: arg,
            items: Map.fetch!(@dishes, arg)
          })

          conn
          |> put_coins(coins - pay)
          |> Helpers.broadcast_vision(
            room_id,
            "【江湖通告】#{character.name}现在在#{hall}#{phrase}。\n\n"
          )
        end
    end
  end

  defp end_banquet(conn, room_id) do
    %{short: short} = Map.fetch!(@halls, room_id)
    # LPC: delete order_owner/order_type + destruct 房内非玩家物品 → 清房 state
    Room.put_state_by_id(room_id, @state_key, nil)

    Helpers.broadcast_vision(conn, room_id, "【江湖通告】#{short}的宴会结束了。\n\n")
  end

  # ---- broadcast ------------------------------------------------------------

  defp do_broadcast(conn, room_id) do
    character = current(conn)

    case state_owner(room_id) do
      owner when owner == character.id ->
        %{hall: hall} = Map.fetch!(@halls, room_id)
        {_check, _pay, phrase} = Map.fetch!(@types, state_type(room_id))

        Helpers.broadcast_vision(
          conn,
          room_id,
          "【江湖通告】#{character.name}现在在#{hall}#{phrase}。\n\n"
        )

      _ ->
        # LPC do_broadcast 非主人 `return 0`；这里给可读反馈（不接管全局命令）
        Helpers.render_to_player(conn, "你不是本宴的主人，无法广播。\n")
    end
  end

  # ---- 小工具 ----------------------------------------------------------------

  defp state_owner(room_id) do
    case Room.get_state_by_id(room_id, @state_key) do
      %{owner: owner} -> owner
      _ -> nil
    end
  end

  defp state_type(room_id) do
    case Room.get_state_by_id(room_id, @state_key) do
      %{type: type} -> type
      _ -> nil
    end
  end

  defp coins_of(character) do
    case character.meta do
      %{coins: coins} when is_integer(coins) -> coins
      _ -> 0
    end
  end

  defp put_coins(conn, coins) do
    character = current(conn)
    put_character(conn, %{character | meta: %{character.meta | coins: coins}})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end

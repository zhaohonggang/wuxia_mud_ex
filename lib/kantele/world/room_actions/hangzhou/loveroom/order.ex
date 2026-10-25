defmodule Kantele.World.RoomActions.Hangzhou.Loveroom.Order do
  @moduledoc """
  P5-9 #9 一次性场景：杭州楼外楼「相约轩」`order`（移植自
  `d/hangzhou/loveroom.c` 的 `do_order`，洞房狂欢，单 20000）。

  LPC 原文：

      int do_order(string arg)
      {
              object me, env;
              object* oblist;
              string mesg;
              int idx;

              me = this_player();
              env = this_object();
              mesg = query("order_owner");
              if (mesg && (arg == "end") && (mesg == me->query("id"))) {
                      mesg = "幽会终于结束了 !!!!!!\n";
                      message("channel:chat", RED+"【江湖通告】"+mesg+NOR, users() );
                      delete_temp("plugin");
                      delete("order_owner");
                      delete("order_type");
                      oblist = all_inventory(env);
                      for(idx=0; idx<sizeof(oblist); idx++) {
                              if (!objectp(oblist[idx])) continue;
                              if (userp(oblist[idx])) continue;
                              destruct(oblist[idx]);
                      }
                      return 1;
              }
              if (mesg)
                      return notify_fail("这里已经被人包租了.\n");
              notify_fail("你没有足够的钱或零钱不够.\n");
              if (arg == "party") {
                      mesg = me->name() + "和某人在杭州楼外楼幽会 !!!!!!\n";
                      if (me->can_afford(20000) == 0)
                              return 0;
                      me->pay_money(20000);
                      create_water(CYN"龙井茶"NOR, ({ "tea" }), MAG"紫砂茶盅"NOR );
                      create_water(HIG"碧螺春"NOR, ({ "tea" }), MAG"紫砂盏"NOR );
                      create_wine(HIY"绍兴黄酒"NOR, ({ "wine" }), HIW"象牙杯"NOR );
                      create_wine(GRN"竹叶青"NOR, ({ "wine" }), HIG"翡翠杯"NOR );
                      create_wine(RED"女儿红"NOR, ({ "wine" }), MAG"紫檀杯"NOR );
                      create_food(RED"东坡肉"NOR, ({ "pork" }) );
                      create_food(HIB"西湖醋鱼"NOR, ({ "fish" }) );
                      create_food(HIR"龙井虾仁"NOR, ({ "shrimp" }) );
                      create_food(YEL"叫化童鸡"NOR, ({ "chicken" }) );
                      create_food(HIR"桂花鲜栗羹"NOR, ({ "guihua geng" }) );
                      create_food(HIY"百果油包"NOR, ({ "baozi" }) );
                      }
               else {
                      return notify_fail("这儿只承办幽会小宴。\n");
              }
              message("channel:chat", RED+"【江湖通告】"+mesg+NOR, users() );
              message("channel:chat", GRN+"【江湖通告】"+mesg+NOR, users() );
              message("channel:chat", CYN+"【江湖通告】"+mesg+NOR, users() );
              set("order_owner", me->query("id"));
              set("order_type", arg);
              return 1;
      }

  UCL 已就绪：`hangzhou:loveroom` 的 `actions` 包含 `order = "do_order"`，**零 UCL 改动**。

  ## 移植要点

  - 只认 `party`（浓情幽会，20000 铜币）与 `end`（结束幽会）。
  - 房 state `loveroom` = `%{owner, type, items}`，用 `Room.get_state_by_id/put_state_by_id`。
  - 钱走扁平货币 `meta.coins`（`can_afford`/`pay_money` 等价 `meta.coins >= 20000` /
    `-= 20000`）。
  - 宴席物品（龙井茶、碧螺春、绍兴黄酒、竹叶青、女儿红、东坡肉、西湖醋鱼、
    龙井虾仁、叫化童鸡、桂花鲜栗羹、百果油包）因 `Room.move_object/2` 尚未落地，
    同 Banquet 一样作为数据记入房 state `items`，不生成实体。
  - 全服 `message("channel:chat", ...)`（江湖通告）用 `broadcast_vision` 投给本房，
    语义近似，非逐字等价（同 Open/Close/Banquet 约定）。
  - `valid_leave`（主人未 end 前不可离场）引擎尚未消费，略过（同 Banquet）。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  @state_key "loveroom"
  @room "hangzhou:loveroom"

  @cost 20_000

  @dishes [
    {:water, "龙井茶", ["tea"], "紫砂茶盅"},
    {:water, "碧螺春", ["tea"], "紫砂盏"},
    {:wine, "绍兴黄酒", ["wine"], "象牙杯"},
    {:wine, "竹叶青", ["wine"], "翡翠杯"},
    {:wine, "女儿红", ["wine"], "紫檀杯"},
    {:food, "东坡肉", ["pork"]},
    {:food, "西湖醋鱼", ["fish"]},
    {:food, "龙井虾仁", ["shrimp"]},
    {:food, "叫化童鸡", ["chicken"]},
    {:food, "桂花鲜栗羹", ["guihua geng"]},
    {:food, "百果油包", ["baozi"]}
  ]

  @impl true
  def run(%{character: nil}, _params), do: :not_handled

  def run(conn, %{room_id: room_id, verb: verb, trailing: trailing}) when is_binary(room_id) do
    if room_id == @room do
      case verb do
        "do_order" -> do_order(conn, room_id, to_string(trailing || ""))
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
        end_order(conn, room_id)

      # LPC: if (mesg) return notify_fail("这里已经被人包租了.\n");
      not is_nil(owner) ->
        Helpers.render_to_player(conn, "这里已经被人包租了。\n")

      true ->
        place_order(conn, room_id, character, arg)
    end
  end

  defp place_order(conn, room_id, character, arg) do
    cond do
      arg != "party" ->
        # LPC: return notify_fail("这儿只承办幽会小宴。\n");
        Helpers.render_to_player(conn, "这儿只承办幽会小宴。\n")

      coins_of(character) < @cost ->
        # LPC: notify_fail("你没有足够的钱或零钱不够。\n");
        Helpers.render_to_player(conn, "你没有足够的钱或零钱不够。\n")

      true ->
        %{name: name} = character

        Room.put_state_by_id(room_id, @state_key, %{
          owner: character.id,
          type: arg,
          items: @dishes
        })

        conn
        |> put_coins(coins_of(character) - @cost)
        |> Helpers.broadcast_vision(
          room_id,
          "【江湖通告】#{name}和某人在杭州楼外楼幽会 !!!!!!\n\n"
        )
    end
  end

  defp end_order(conn, room_id) do
    # LPC: delete order_owner/order_type + destruct 房内非玩家物品 → 清房 state
    Room.put_state_by_id(room_id, @state_key, nil)

    Helpers.broadcast_vision(conn, room_id, "【江湖通告】幽会终于结束了 !!!!!!\n\n")
  end

  # ---- 小工具 ----------------------------------------------------------------

  defp state_owner(room_id) do
    case Room.get_state_by_id(room_id, @state_key) do
      %{owner: owner} -> owner
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

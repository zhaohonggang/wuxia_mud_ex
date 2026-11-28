defmodule Kantele.World.InquiryHandlersHireHelperTest do
  @moduledoc """
  #801 侠客岛黄衣使者雇助：ask_rent 七门 / 师兄弟列表 / try_to_hire 价目表
  + accept_object 付款分支 + 玩家侧销毁钱币与随从跟随。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kantele.Character.BeastState
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.HireHelper
  alias Kantele.World.Items
  alias Kantele.World.XiakedaoRentAccept

  @helper %{
    "id" => "xiakedao_helper_three",
    "name" => "侠客岛弟子丙",
    "npc_level" => 3,
    "combat_exp" => 200_000,
    "family" => "侠客岛"
  }

  setup do
    BeastState.ensure!()
    BeastState.reset()

    Items.put("xiakedao:gold", %Item{
      id: "xiakedao:gold",
      name: "黄金",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"is_money" => true, "amount" => 250_000}
    })

    :ok
  end

  defp player(opts \\ []) do
    # Stats 结构体没有 dps/wpk 字段；LPC 的 combat/DPS、combat/WPK
    # 在本端口是可选扩展键，测试用裸 map 直接注入。
    stats = %{
      combat_exp: Keyword.get(opts, :combat_exp, 500_000),
      score: Keyword.get(opts, :score, 20_000),
      weiwang: Keyword.get(opts, :weiwang, 2_000),
      dps: Keyword.get(opts, :dps, 0),
      wpk: Keyword.get(opts, :wpk, 0),
      skills: %{}
    }

    temp = Keyword.get(opts, :temp, %{})

    %Conn{
      character: %Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xiakedao:test",
        meta: %PlayerMeta{vitals: %Vitals{qi: 100}, stats: stats, temp: temp}
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp npc_conn(helpers \\ [@helper]) do
    %Conn{
      character: %Character{
        id: "xiakedao_renter",
        name: "黄衣使者",
        room_id: "xiakedao:test",
        meta: %NonPlayerMeta{
          inquiry_state: %{"rent_helpers" => helpers},
          combat_config: nil,
          combat: nil
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "xiakedao_renter",
      npc_name: "黄衣使者",
      npc_pid: self(),
      npc_room_id: "xiakedao:test",
      npc_family: "侠客岛",
      perform_name: Keyword.get(opts, :perform_name, ""),
      helpers: Keyword.get(opts, :helpers, [@helper])
    }
  end

  defp updated(conn) do
    Map.get(conn.private || %{}, :update_character) || conn.character
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: text} -> text
      %Conn.EventText{text: %Conn.Text{data: text}} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  defp publishes(conn) do
    Enum.filter(conn.private.channel_changes, fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _channel, event, _options, _fun} -> event.data.text end)
  end

  describe "ask_rent 七道门（LPC renter.c:125-151）" do
    test "weiwang < 1000" do
      result = HireHelper.run(player(weiwang: 999), %{}, data())

      assert output_text(result) =~ "你这点名头也能使唤人？算了吧！"
    end

    test "score < 10000" do
      result = HireHelper.run(player(score: 9_999), %{}, data())

      assert output_text(result) =~ "你江湖阅历太浅，还是免了。"
    end

    test "combat_exp < 100000" do
      result = HireHelper.run(player(combat_exp: 99_999), %{}, data())

      assert output_text(result) =~ "你的武功太差，想支使谁呀？"
    end

    test "combat/DPS > 30 与 combat/WPK > 30 分别拒绝" do
      assert output_text(HireHelper.run(player(dps: 31), %{}, data())) =~
               "你这人，伤人太多"

      assert output_text(HireHelper.run(player(wpk: 31), %{}, data())) =~
               "辣手无情，杀人无算"
    end

    test "已有同门随从" do
      conn = player(temp: %{"hire" => [@helper]})
      result = HireHelper.run(conn, %{}, data())

      assert output_text(result) =~ "现在不是有侠客岛弟子丙和你在一起么？"
    end

    test "无可用师兄弟" do
      result = HireHelper.run(player(), %{}, data(helpers: []))

      assert output_text(result) =~ "我的师兄弟都走啦，你还是等两天再来吧。"
    end
  end

  describe "ask_rent 列表（LPC renter.c:153-172）" do
    test "列出全部 helper，按等级排序并带随机收尾" do
      result = HireHelper.run(player(), %{"closing" => "test closing"}, data())

      [text] = publishes(result)
      assert text =~ "{npc}笑了笑，道：“现在我身边的师兄弟有这么几个，你看看吧。”"
      assert text =~ "侠客岛弟子丙(xiakedao_helper_three)"
      assert text =~ "等级：3"
      assert text =~ "test closing"
    end
  end

  describe "try_to_hire（LPC renter.c:267-297）" do
    test "已有同门 → 拒绝文案与 ask_rent 不同" do
      conn = player(temp: %{"hire" => [@helper]})

      result =
        HireHelper.run(conn, %{"mode" => "hire"}, data(perform_name: "xiakedao_helper_three"))

      assert output_text(result) =~ "现在不是正和你在一起么？还不够啊？"
    end

    test "玩家 exp 低于 helper exp 的 2/3 → 拒绝" do
      conn = player(combat_exp: 100_000)

      result =
        HireHelper.run(conn, %{"mode" => "hire"}, data(perform_name: "xiakedao_helper_three"))

      assert output_text(result) =~ "武功也强你太多"
    end

    test "玩家 exp 高于 helper exp 的 2 倍 → 拒绝" do
      conn = player(combat_exp: 400_001)

      result =
        HireHelper.run(conn, %{"mode" => "hire"}, data(perform_name: "xiakedao_helper_three"))

      assert output_text(result) =~ "恐怕帮不上你什么忙吧"
    end

    test "exp 比例通过 → 按 npc_level 3 定价 25 两，写 pending/rent" do
      conn = player(combat_exp: 200_000)

      result =
        HireHelper.run(conn, %{"mode" => "hire"}, data(perform_name: "xiakedao_helper_three"))

      [combined] = publishes(result)
      assert combined =~ "我们侠客岛开销也不小的"
      assert combined =~ "二十五两黄金"

      temp = updated(result).meta.temp
      assert Map.get(temp, "pending/rent/cost") == 25
      assert Map.get(temp, "pending/rent/helper")["id"] == "xiakedao_helper_three"
      assert Map.get(temp, "pending/rent")["cost"] == 25
    end

    test "exp 边界：2/3 与 2 倍都可通过" do
      low =
        HireHelper.run(
          player(combat_exp: 133_334),
          %{"mode" => "hire"},
          data(perform_name: "xiakedao_helper_three")
        )

      high =
        HireHelper.run(
          player(combat_exp: 400_000),
          %{"mode" => "hire"},
          data(perform_name: "xiakedao_helper_three")
        )

      refute output_text(low) =~ "强你太多"
      refute output_text(high) =~ "帮不上你"
    end
  end

  describe "accept_object（LPC renter.c:175-246）" do
    defp money_instance(id \\ "inst-gold") do
      %Item.Instance{id: id, item_id: "xiakedao:gold", created_at: DateTime.utc_now()}
    end

    defp give_data(opts \\ []) do
      %{
        reply_to: self(),
        from_id: "player:test",
        from_name: "测试玩家",
        npc_room_id: "xiakedao:test",
        respect: "大侠",
        pending_rent: Keyword.get(opts, :pending_rent),
        treat_skill: Keyword.get(opts, :treat_skill, false)
      }
    end

    test "无 pending/rent → 说「赞助我们侠客岛么」" do
      result =
        XiakedaoRentAccept.handle(
          npc_conn(),
          npc_conn().character,
          money_instance(),
          give_data(),
          "测试玩家"
        )

      assert publishes(result) |> Enum.join() =~ "你给我钱干什么？赞助我们侠客岛么？"
    end

    test "钱不足且无 treat → 只说不能打折" do
      pending = %{"cost" => 30, "helper" => @helper}

      result =
        XiakedaoRentAccept.handle(
          npc_conn(),
          npc_conn().character,
          money_instance(),
          give_data(pending_rent: pending),
          "测试玩家"
        )

      assert publishes(result) |> Enum.join() =~ "我们这里可不能打折"
      refute_receive %Kalevala.Event{topic: "xiakedao/rent_return"}, 50
    end

    test "钱不足但有 treat 且 n*2 >= cost → 怜悯分支后成交" do
      pending = %{"cost" => 40, "helper" => @helper}

      result =
        XiakedaoRentAccept.handle(
          npc_conn(),
          npc_conn().character,
          money_instance(),
          give_data(pending_rent: pending, treat_skill: true),
          "测试玩家"
        )

      assert publishes(result) |> Enum.join() =~ "可怜可怜我这穷鬼吧"
      assert_receive %Kalevala.Event{topic: "xiakedao/rent_return", data: %{discount: true}}, 200
    end

    test "足额 → 发回执并从可雇列表移除 helper" do
      pending = %{"cost" => 25, "helper" => @helper}
      conn = npc_conn()

      result =
        XiakedaoRentAccept.handle(
          conn,
          conn.character,
          money_instance(),
          give_data(pending_rent: pending),
          "测试玩家"
        )

      assert publishes(result) |> Enum.join() =~ "送钱的上门了"

      assert_receive %Kalevala.Event{
                       topic: "xiakedao/rent_return",
                       data: %{
                         cost: 25,
                         discount: false,
                         helper: %{"id" => "xiakedao_helper_three"}
                       }
                     },
                     200

      assert updated(result).meta.inquiry_state["rent_helpers"] == []
    end
  end

  describe "玩家侧回执" do
    test "销毁钱币、写 hire、清 pending、生成随从并建立 BeastState" do
      instance = %Item.Instance{
        id: "inst-gold",
        item_id: "xiakedao:gold",
        created_at: DateTime.utc_now()
      }

      conn = %{
        player()
        | character: %{player().character | inventory: [instance]}
      }

      conn = %{
        conn
        | private:
            Map.put(conn.private, :xiakedao_spawn_helper, fn helper, room_id ->
              %{
                id: "spawned:#{helper["id"]}",
                name: helper["name"],
                pid: self(),
                room_id: room_id
              }
            end)
      }

      data = %{
        from_id: "player:test",
        from_name: "测试玩家",
        npc_room_id: "xiakedao:test",
        instance_id: "inst-gold",
        helper: @helper,
        cost: 25
      }

      result = GiveEvent.xiakedao_rent_returned(conn, %{data: data})

      player_after = updated(result)
      assert player_after.inventory == []
      assert Enum.map(player_after.meta.temp["hire"], & &1["id"]) == ["xiakedao_helper_three"]
      refute Map.has_key?(player_after.meta.temp, "pending/rent")

      state = BeastState.get("spawned:xiakedao_helper_three")
      assert state.owner_id == "player:test"
      assert state.leader_id == "player:test"
      assert is_integer(state.help_time)

      assert_receive %Kalevala.Event{topic: "follow/set-leader"}, 200
      assert_receive %Kalevala.Event{topic: "follow/register"}, 200
    end
  end
end

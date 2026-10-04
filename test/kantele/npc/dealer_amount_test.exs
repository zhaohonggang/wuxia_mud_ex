defmodule Kantele.Npc.DealerAmountTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.Dealer

  # dealer.ex 里 `Map.get(item, :amount, 1) < 1` 永远不成立（默认值 1），
  # 于是「不可叠加的物品不能拆开卖 / 不能一次买多个」这两条拒绝分支
  # 一直是死代码。LPC dealer.c 靠 `query_amount()` 返回 **0** 表示不可叠加。
  #
  # 语义：`:amount` **缺失** = 不可叠加（数量上限 1）；
  # `:amount` 存在且 > 0 = 可叠加。

  defp item(overrides \\ %{}) do
    Map.merge(%{id: "test:sword", name: "钢刀", value: 100, base_value: 100, unit: "柄"}, overrides)
  end

  describe "stackable?/1" do
    test ":amount 缺失 = 不可叠加（LPC query_amount() 返回 0）" do
      refute Dealer.stackable?(item())
    end

    test ":amount 存在且 > 0 = 可叠加" do
      assert Dealer.stackable?(item(%{amount: 3}))
    end

    test ":amount 为 0 = 不可叠加" do
      refute Dealer.stackable?(item(%{amount: 0}))
    end
  end

  describe "do_sell/2 —— 不可叠加的物品" do
    test "amount > 1 时被拒（这条分支以前是死代码）" do
      assert {:reject, msg} = Dealer.do_sell(item(), 2)
      assert msg =~ "不能拆开来卖"
    end

    test "amount == 1 时正常报价" do
      assert {:ok, value} = Dealer.do_sell(item(), 1)
      # LPC: value * 3 / 10 = 100 * 3 / 10 = 30
      assert value == 30
    end
  end

  describe "do_sell/2 —— 可叠加的物品" do
    test "amount 超过库存被拒" do
      assert {:reject, msg} = Dealer.do_sell(item(%{amount: 2}), 5)
      assert msg =~ "没有这么多"
    end

    test "amount <= 库存时按 base_value * amount 计价" do
      # LPC dealer.c:184: `if (max_count > 1) value = base_value * amount`
      # amount=2, base_value=100 -> 200 * 3 / 10 = 60
      assert {:ok, 60} = Dealer.do_sell(item(%{amount: 2, value: 100, base_value: 100}), 2)
    end

    test "amount == 1 但库存叠了 4 件时，仍走 base_value 分支（LPC 判的是 max_count）" do
      # LPC dealer.c:184 `if (max_count > 1) value = base_value * amount;`
      # 条件是**库存数量** max_count，不是本次卖出的 amount。
      # 叠了 4 件的钢刀卖 1 件 -> base_value(9999) * 1 * 3 / 10 = 2999
      assert {:ok, 2999} =
               Dealer.do_sell(
                 item(%{amount: 4, value: 100, base_value: 9999}),
                 1
               )
    end

    test "库存只有 1 件（不可叠加）时按单件 value 计价" do
      assert {:ok, 30} =
               Dealer.do_sell(
                 item(%{value: 100, base_value: 9999}),
                 1
               )
    end
  end

  describe "do_sell/2 —— LPC dealer.c 的其它拒绝分支" do
    test "amount < 1" do
      assert {:reject, msg} = Dealer.do_sell(item(), 0)
      assert msg =~ "亏你想的出来"
    end

    test "卖掉自己的店货被拒（LPC:160 is_vendor_good）" do
      assert {:reject, msg} = Dealer.do_sell(item(%{vendor_good: true}), 1)
      assert msg =~ "我卖给你好不好"
    end

    test "少林庙产不收" do
      assert {:reject, msg} = Dealer.do_sell(item(%{shaolin?: true}), 1)
      assert msg =~ "少林庙产"
    end

    test "魔教的东西不收" do
      assert {:reject, msg} = Dealer.do_sell(item(%{mingjiao?: true}), 1)
      assert msg =~ "魔教"
    end

    test "剩菜剩饭不收" do
      assert {:reject, msg} = Dealer.do_sell(item(%{food_supply?: true}), 1)
      assert msg =~ "剩菜剩饭"
    end

    test "钱不能卖" do
      assert {:reject, msg} = Dealer.do_sell(item(%{money_id: "gold"}), 1)
      assert msg =~ "钱"
    end

    test "人不卖" do
      assert {:reject, msg} = Dealer.do_sell(item(%{is_character?: true}), 1)
      assert msg =~ "正经生意"
    end
  end

  describe "check_buy_preconditions/1 —— LPC dealer.c:337-364 的 4 道前置检查" do
    test "正常情况放行" do
      assert {:ok, nil} =
               Dealer.check_buy_preconditions(%{
                 carried_count: 3,
                 start_room: "city:jiulou",
                 current_room: "city:jiulou"
               })
    end

    test "身上东西太多被拒（对应 LPC MAX_ITEM_CARRIED）" do
      assert {:reject, msg} =
               Dealer.check_buy_preconditions(%{
                 carried_count: 100,
                 start_room: "city:jiulou",
                 current_room: "city:jiulou"
               })

      assert msg =~ "身上的东西太多了"
    end

    test "交易冷却中被拒（对应 LPC 的 busy 标记）" do
      assert {:reject, msg} =
               Dealer.check_buy_preconditions(%{
                 carried_count: 1,
                 busy?: true,
                 start_room: "city:jiulou",
                 current_room: "city:jiulou"
               })

      assert msg =~ "正忙着"
    end

    test "NPC 跑偏到别的房间 -> 传送回 startroom（防走丢自愈）" do
      assert {:recover, plan} =
               Dealer.check_buy_preconditions(%{
                 carried_count: 1,
                 start_room: "city:jiulou",
                 current_room: "city:duchang",
                 still_listed?: true
               })

      assert plan.action == :teleport_home
      assert plan.room_id == "city:jiulou"
      assert plan.message =~ "跑到这儿来了"
    end

    test "跑偏且已不在 startroom 的对象表里 -> 自杀（LPC destruct）" do
      assert {:recover, plan} =
               Dealer.check_buy_preconditions(%{
                 carried_count: 1,
                 start_room: "city:jiulou",
                 current_room: "city:duchang",
                 still_listed?: false
               })

      assert plan.action == :despawn
    end

    test "卖 carried_goods 的 NPC 不做跑偏自愈（LPC carried_goods 例外）" do
      assert {:ok, nil} =
               Dealer.check_buy_preconditions(%{
                 carried_count: 1,
                 carried_goods?: true,
                 start_room: "city:jiulou",
                 current_room: "city:duchang"
               })
    end
  end

  describe "reset_plan/2 —— LPC reset()" do
    test "正常库存无需清理" do
      assert Dealer.reset_plan([%{id: "a", count: 1, weight: 10}]) == :ok
    end

    test "数量超过上限的会被列出待销毁" do
      ids =
        Dealer.reset_plan([
          %{id: "ok", count: 1, weight: 10},
          %{id: "too_many", count: 200, weight: 10}
        ])

      assert ids == ["too_many"]
    end

    test "单件超重的会被列出待销毁（LPC: obs[i]->query_weight() >= 1000000）" do
      ids = Dealer.reset_plan([%{id: "heavy", count: 1, weight: 1_000_000}])

      assert ids == ["heavy"]
    end

    test "上限可覆盖" do
      assert Dealer.reset_plan([%{id: "x", count: 5}], max_count: 10) == :ok
    end
  end

  describe "destruct_it_plan/1 与 enough_rest_plan/0" do
    test "临时物品销毁计划（LPC call_out destruct_it, 0）" do
      assert Dealer.destruct_it_plan("city:jitui") ==
               %{action: :destroy_temp_item, item_id: "city:jitui"}
    end

    test "冷却清除计划是 1 秒（LPC call_out enough_rest, 1）" do
      assert Dealer.enough_rest_plan() == %{action: :clear_busy, delay_ms: 1000}
    end
  end

  describe "do_buy/4 —— 不可叠加的物品只能买一个" do
    test "amount > 1 被拒（这条分支以前是死代码）" do
      assert {:reject, msg} = Dealer.do_buy(item(), 3, %{})
      assert msg =~ "只能一个一个的买"
    end

    test "amount == 1 正常" do
      assert {:ok, 100} = Dealer.do_buy(item(), 1, %{})
    end

    test "可叠加物品可以买多个" do
      assert {:ok, _} = Dealer.do_buy(item(%{amount: 5}), 3, %{})
    end

    test "一次最多 100 件" do
      assert {:reject, msg} = Dealer.do_buy(item(%{amount: 200}), 101, %{})
      assert msg =~ "最多买一百件"
    end
  end
end
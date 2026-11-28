defmodule Kantele.World.SingletonItemsTest do
  @moduledoc """
  #893 全服单件物品（LPC /clone/lonely/*）持有者遍历。

  LPC zuo.c create()：残阳宝剑无 environment → 发给该 NPC；已有持有者 →
  fallback 普通长剑。ex 侧用 SingletonItems ETS 登记"已发放"，SpawnController
  equip_carry 消费；发放后不回池（尸体腐烂是把物品 move(env)，不销毁），
  重启清空 = LPC 重启后 find_object 重新 load 的回池语义。
  """

  use ExUnit.Case, async: false

  alias Kantele.World.Loader
  alias Kantele.World.SingletonItems

  setup do
    # 独立表名做不到（模块写死 @table），async: false 下串行清理即可
    SingletonItems.init()
    on_exit(fn ->
      case :ets.whereis(:kantele_singleton_items) do
        :undefined -> :ok
        _ -> :ets.delete_all_objects(:kantele_singleton_items)
      end
    end)

    :ok
  end

  describe "SingletonItems 登记表" do
    test "未登记时 taken? 为 false，register 后为 true" do
      refute SingletonItems.taken?("clone_lib:canyang")
      :ok = SingletonItems.register("clone_lib:canyang")
      assert SingletonItems.taken?("clone_lib:canyang")
      assert not SingletonItems.taken?("clone_lib:changjian")
    end

    test "init 幂等（重复创建不崩）" do
      :ok = SingletonItems.init()
      :ok = SingletonItems.init()
      assert :ets.whereis(:kantele_singleton_items) != :undefined
    end
  end

  setup_all do
    world = Loader.load()

    zuo =
      Enum.find(world.characters, fn c ->
        c.name == "左冷禅" and Map.get(c.meta, :zone_id) == "songshan"
      end) || raise("左冷禅 not found")

    %{carry: Map.get(zuo.meta, :carry)}
  end

  describe "UCL 加载（左冷禅）" do

    test "carry 的 singleton 项结构正确（id/fallback 已解引用）", %{carry: carry} do
      entry = Enum.find(carry, &is_map/1) || raise("no singleton entry")

      assert entry == %{
               id: "clone_lib:canyang",
               singleton: true,
               fallback: "clone_lib:changjian"
             }

      # cloth 仍是普通字符串项（零回归）
      assert "clone_lib:cloth" in carry
    end

    test "canyang 物品定义存在于世界（clone_lib 单件）" do
      world = Loader.load()
      item = Enum.find(world.items, &(&1.id == "clone_lib:canyang"))

      assert item && item.name == "残阳宝剑"
      assert Map.get(item.meta, :no_sell)
    end
  end
end

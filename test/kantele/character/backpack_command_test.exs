defmodule Kantele.Character.BackpackCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.BackpackCommand
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @drink_verb %Kalevala.Verb{
    key: :drink,
    icon: "drink",
    text: "喝",
    send: "drink ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  @clone_verb %Kalevala.Verb{
    key: :clone,
    icon: "clone",
    text: "克隆",
    send: "clone ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  setup do
    Items.put("test:bag", %Item{
      id: "test:bag",
      name: "布包",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{storage_bag: 5}
    })

    Items.put("test:baozi", %Item{
      id: "test:baozi",
      name: "包子 Baozi",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{}
    })

    Items.put("test:mantou", %Item{
      id: "test:mantou",
      name: "馒头 Mantou",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{food: 30}
    })

    Items.put("test:jiu", %Item{
      id: "test:jiu",
      name: "女儿红 Nverhong",
      verbs: [@drink_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{}
    })

    Items.put("test:sword", %Item{
      id: "test:sword",
      name: "铁剑 Tiejian",
      verbs: [@clone_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{damage: 22}
    })

    :ok
  end

  defp player(inventory \\ [], opts \\ []) do
    extra = Keyword.get(opts, :bag, [])

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        bag: extra,
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp instance(item_id, id \\ nil) do
    %Item.Instance{
      id: id || "instance-#{item_id}",
      item_id: item_id,
      created_at: DateTime.utc_now()
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_meta(conn), do: (conn.private.update_character || conn.character).meta

  defp updated_inventory(conn),
    do: (conn.private.update_character || conn.character).inventory

  defp player_with_bag do
    player([instance("test:bag"), instance("test:baozi")])
  end

  describe "路由解析" do
    test "store 系列动词" do
      {:ok, parsed} = Kantele.Character.Commands.parse("store 包子")
      assert parsed.module == BackpackCommand
      assert parsed.function == :store
      assert parsed.params["rest"] == "包子"

      {:ok, parsed} = Kantele.Character.Commands.parse("store all")
      assert parsed.function == :store
      assert parsed.params["rest"] == "all"

      {:ok, parsed} = Kantele.Character.Commands.parse("store")
      assert parsed.function == :store_bare
    end

    test "take 与 背包" do
      {:ok, parsed} = Kantele.Character.Commands.parse("take 1 3")
      assert parsed.module == BackpackCommand
      assert parsed.function == :take
      assert parsed.params["rest"] == "1 3"

      {:ok, parsed} = Kantele.Character.Commands.parse("take")
      assert parsed.function == :take_bare

      {:ok, parsed} = Kantele.Character.Commands.parse("背包")
      assert parsed.module == BackpackCommand
      assert parsed.function == :list
    end
  end

  describe "背包解锁（storage_bag 判定）" do
    test "没有背包容器时 store/take/背包 均拒绝" do
      p = player([instance("test:baozi")])

      conn = BackpackCommand.store(build_conn(p), %{"rest" => "包子"})
      assert output_text(conn) =~ "你还没有背包呢"

      conn = BackpackCommand.take(build_conn(p), %{"rest" => "1 1"})
      assert output_text(conn) =~ "你还没有背包呢"

      conn = BackpackCommand.list(build_conn(p), %{})
      assert output_text(conn) =~ "你还没有背包呢"
    end

    test "持有 storage_bag=5 的容器即可解锁（背包查看/裸 store）" do
      conn = BackpackCommand.list(build_conn(player_with_bag()), %{})
      assert output_text(conn) =~ "你的背包里没有存放任何物品"

      # 裸 store 走 do_store("") 分支，越过解锁/忙碌检查后提示缺参数
      conn = BackpackCommand.store_bare(build_conn(player_with_bag()), %{})
      assert output_text(conn) =~ "你要存放什么东西"
    end
  end

  describe "store" do
    test "存一件：背包减少、包内新增一条" do
      conn = BackpackCommand.store(build_conn(player_with_bag()), %{"rest" => "包子"})

      assert output_text(conn) =~ "你把包子"
      assert updated_inventory(conn) |> Enum.map(& &1.item_id) == ["test:bag"]

      bag = PlayerMeta.bag(updated_meta(conn))
      assert bag == [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 1}]
    end

    test "存数量：store 2 包子 合并为一条 amount=2" do
      p = player([instance("test:bag"), instance("test:baozi"), instance("test:baozi")])
      conn = BackpackCommand.store(build_conn(p), %{"rest" => "2 包子"})

      assert output_text(conn) =~ "你把2个包子"
      assert updated_inventory(conn) |> Enum.map(& &1.item_id) == ["test:bag"]

      bag = PlayerMeta.bag(updated_meta(conn))
      assert [%{file: "test:baozi", amount: 2}] = bag
    end

    test "同名数量不足时拒绝" do
      p = player([instance("test:bag"), instance("test:baozi")])
      conn = BackpackCommand.store(build_conn(p), %{"rest" => "3 包子"})

      assert output_text(conn) =~ "你没有那么多的包子"
      assert updated_inventory(conn) |> Enum.map(& &1.item_id) == ["test:bag", "test:baozi"]
      assert PlayerMeta.bag(updated_meta(conn)) == []
    end

    test "食物/液体不可入包" do
      conn = BackpackCommand.store(build_conn(player([instance("test:bag"), instance("test:mantou")])), %{"rest" => "馒头"})
      assert output_text(conn) =~ "食物饮水存背包里会变质的"

      conn = BackpackCommand.store(build_conn(player([instance("test:bag"), instance("test:jiu")])), %{"rest" => "女儿红"})
      assert output_text(conn) =~ "食物饮水存背包里会变质的"
    end

    test "已装备物品不可入包" do
      equipped = %{weapon: %{name: "铁剑 Tiejian", damage: 22}}
      p = %{player([instance("test:bag"), instance("test:sword")]) | meta: %{player().meta | combat: %{player().meta.combat | equipped: equipped}}}
      conn = BackpackCommand.store(build_conn(p), %{"rest" => "铁剑"})

      assert output_text(conn) =~ "必须先脱离装备才能存放"
      assert PlayerMeta.bag(updated_meta(conn)) == []
    end

    test "身上没有这样东西" do
      conn = BackpackCommand.store(build_conn(player_with_bag()), %{"rest" => "宝剑"})
      assert output_text(conn) =~ "你身上没有这样东西"
    end

    test "裸 store 提示" do
      conn = BackpackCommand.store_bare(build_conn(player_with_bag()), %{})
      assert output_text(conn) =~ "你要存放什么东西"
    end
  end

  describe "store all" do
    test "跳过食物/液体，只存可存物品" do
      p =
        player([
          instance("test:bag"),
          instance("test:baozi"),
          instance("test:sword"),
          instance("test:mantou")
        ])

      conn = BackpackCommand.store(build_conn(p), %{"rest" => "all"})

      # 消息用第一件物品命名：包子 Baozi
      assert output_text(conn) =~ "你把2个包子"

      stored =
        PlayerMeta.bag(updated_meta(conn))
        |> Enum.map(& &1.file)
        |> Enum.sort()

      assert stored == ["test:baozi", "test:sword"]
      assert updated_inventory(conn) |> Enum.map(& &1.item_id) == ["test:bag", "test:mantou"]
    end

    test "没有可存物品时提示" do
      conn = BackpackCommand.store(build_conn(player([instance("test:bag"), instance("test:mantou")])), %{"rest" => "all"})

      assert output_text(conn) =~ "你身上没有任何可以保存的物品"
    end
  end

  describe "take" do
    test "按编号取回：重建实例入背包，包内条目移除" do
      p = %{player([instance("test:bag")]) | meta: PlayerMeta.put_bag(player().meta, [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 1}])}
      conn = BackpackCommand.take(build_conn(p), %{"rest" => "1 1"})

      assert output_text(conn) =~ "你从背包里取出包子"
      assert updated_inventory(conn) |> Enum.map(& &1.item_id) == ["test:baozi", "test:bag"]
      assert PlayerMeta.bag(updated_meta(conn)) == []
    end

    test "部分取出：条目扣减而不移除" do
      p = %{player_with_bag() | meta: PlayerMeta.put_bag(player().meta, [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 5}])}
      conn = BackpackCommand.take(build_conn(p), %{"rest" => "1 2"})

      assert output_text(conn) =~ "你从背包里取出2个包子"
      bag = PlayerMeta.bag(updated_meta(conn))
      assert bag == [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 3}]
    end

    test "单参按数量 1 取" do
      p = %{player_with_bag() | meta: PlayerMeta.put_bag(player().meta, [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 3}])}
      conn = BackpackCommand.take(build_conn(p), %{"rest" => "1"})

      assert output_text(conn) =~ "你从背包里取出包子"
      assert [%{amount: 2}] = PlayerMeta.bag(updated_meta(conn))
    end

    test "越界/超量提示" do
      p = %{player_with_bag() | meta: PlayerMeta.put_bag(player().meta, [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 1}])}

      conn = BackpackCommand.take(build_conn(p), %{"rest" => "2 1"})
      assert output_text(conn) =~ "你的背包里没有存放这项物品"

      conn = BackpackCommand.take(build_conn(player_with_bag()), %{"rest" => "1 1"})
      assert output_text(conn) =~ "你的背包里没有存放任何物品"

      conn = BackpackCommand.take(build_conn(player_with_bag()), %{"rest" => "0 1"})
      assert output_text(conn) =~ "你要取第几号物品"
    end

    test "格式错误提示" do
      conn = BackpackCommand.take(build_conn(player_with_bag()), %{"rest" => "abc"})
      assert output_text(conn) =~ "格式错误"

      conn = BackpackCommand.take_bare(build_conn(player_with_bag()), %{})
      assert output_text(conn) =~ "格式错误"
    end

    test "一次取太多拒绝" do
      conn = BackpackCommand.take(build_conn(player_with_bag()), %{"rest" => "1 20000"})
      assert output_text(conn) =~ "不得小于 1 同时也不能大于 10000"
    end

    test "模板失效时清除该格" do
      p = %{player_with_bag() | meta: PlayerMeta.put_bag(player().meta, [%{file: "test:ghost", name: "幽灵", id: "ghost", amount: 1}])}
      conn = BackpackCommand.take(build_conn(p), %{"rest" => "1 1"})

      assert output_text(conn) =~ "无法取出该物品，系统自动清除之"
      assert PlayerMeta.bag(updated_meta(conn)) == []
    end
  end

  describe "忙碌/战斗拦截" do
    test "busy 中拒绝" do
      busy = %{player_with_bag() | meta: %{player().meta | combat: %{Combat.new() | busy: 1}}}
      conn = BackpackCommand.store(build_conn(busy), %{"rest" => "包子"})
      assert output_text(conn) =~ "你正忙着呢"
      assert PlayerMeta.bag(updated_meta(conn)) == []
    end

    test "战斗中拒绝" do
      fighting = %{player_with_bag() | meta: %{player().meta | combat: %{Combat.new() | enemies: [%{id: "e1"}]}}}
      conn = BackpackCommand.store(build_conn(fighting), %{"rest" => "包子"})
      assert output_text(conn) =~ "你正在战斗中呢"
      assert PlayerMeta.bag(updated_meta(conn)) == []
    end
  end

  describe "容量上限" do
    test "容量满时拒绝存入" do
      # combat_exp 0 → capacity 9；持有 storage_bag=5 容器 → 总容量 14
      p =
        player([instance("test:bag"), instance("test:baozi")],
          bag: for(i <- 1..14, do: %{file: "f#{i}", name: "x", id: "x", amount: 1})
        )

      p = %{p | meta: %{p.meta | stats: struct(Stats.new(), combat_exp: 0)}}
      conn = BackpackCommand.store(build_conn(p), %{"rest" => "包子"})

      assert output_text(conn) =~ "储藏空间全被使用了"
      assert PlayerMeta.bag(updated_meta(conn)) |> length() == 14
    end
  end

  describe "背包查询" do
    test "列出已存物品" do
      p =
        %{player_with_bag() | meta: PlayerMeta.put_bag(player().meta, [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 2}])}

      conn = BackpackCommand.list(build_conn(p), %{})

      assert output_text(conn) =~ "你的背包里存放的物品有"
      assert output_text(conn) =~ "包子"
      # player_with_bag 持有 storage_bag=5 → capacity 9+5=14
      assert output_text(conn) =~ "已用 1/14 格"
    end

    test "storage_bag 扩展格会计入容量" do
      p =
        player([instance("test:bag")],
          bag: [%{file: "test:baozi", name: "包子 Baozi", id: "test:baozi", amount: 1}]
        )

      conn = BackpackCommand.list(build_conn(p), %{})
      # capacity: combat_exp 0 → 9 + storage_bag 5 = 14
      assert output_text(conn) =~ "已用 1/14 格"
    end
  end
end
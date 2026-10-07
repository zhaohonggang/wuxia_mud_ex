defmodule Kantele.World.ItemResolveTest do
  use ExUnit.Case, async: false

  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items
  alias Kantele.World.Item, as: WorldItem

  @real "liuxi:baozi"
  @gone "global:potion"

  setup do
    Items.put(@real, %Item{
      id: @real,
      name: "包子 Baozi",
      description: "一个热腾腾的包子。",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{unit: "个"}
    })

    :ok
  end

  defp instance(item_id) do
    %Instance{
      id: "inst-#{item_id}",
      item_id: item_id,
      item: %Item.ItemNotLoaded{},
      meta: %{}
    }
  end

  describe "fetch/1 —— 定义缺失时不 raise" do
    test "有定义时返回真物品" do
      item = WorldItem.fetch(@real)

      assert item.id == @real
      assert item.name == "包子 Baozi"
    end

    test "没定义时返回占位物品而不是抛异常" do
      # 这条是回归测试：`test` / `global` 两个夹具区搬走之后，数据库里
      # 还留着 `global:potion` 这种 item_id。曾经 `Items.get!/1` 在这里
      # raise「Could not find key global:potion in cache」，把登录中的
      # Foreman GenServer 整个带走。
      assert WorldItem.fetch(@gone) == %Item{
               id: @gone,
               name: "未知物品（global:potion）",
               description: "这件物品的定义不在世界数据里。",
               meta: %{}
             }
    end

    test "对完全没见过的 id 也一样不炸" do
      assert %Item{id: "no:such_thing"} = WorldItem.fetch("no:such_thing")
    end
  end

  describe "resolve/1" do
    test "填上真定义" do
      resolved = WorldItem.resolve(instance(@real))

      assert resolved.item.name == "包子 Baozi"
      assert resolved.id == "inst-#{@real}"
    end

    test "定义缺失时填占位物品，实例本身保持不变" do
      original = instance(@gone)
      resolved = WorldItem.resolve(original)

      assert resolved.item.id == @gone
      assert resolved.item_id == @gone
      assert resolved.meta == %{}
    end
  end

  describe "背包渲染不再受缺失定义影响" do
    test "同时有真物品和悬空物品时都能列出来" do
      # InventoryEvent.list/2 用的是 WorldItem.resolve/1，所以这里覆盖的是
      # 「登录时列背包」这条路径 —— 之前只要有一件查不到定义的角色就登不进来。
      resolved =
        [instance(@real), instance(@gone)]
        |> Enum.map(&WorldItem.resolve/1)
        |> Enum.map(& &1.item.name)

      assert resolved == ["包子 Baozi", "未知物品（global:potion）"]
    end
  end

  describe "materialize_book/2 —— 实例化时掷骰（wuji 随机秘籍）" do
    alias Kantele.World.Item.Meta.Book

    defp book_item(book_meta) do
      %Item{
        id: "test:wuji",
        name: "无名秘籍",
        description: "这是一册不知名目的武学秘籍。",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %{book: book_meta}
      }
    end

    @wuji_skills [
      %{name: "罗汉拳法", skill: "luohan-quan"},
      %{name: "般若掌法", skill: "banruo-zhang"},
      %{name: "大金刚拳", skill: "jingang-quan"}
    ]

    test "带 skills 候选列表时随机定一支（技能与标题都来自候选）" do
      rolled =
        for _ <- 1..30 do
          instance = %Instance{id: "wuji-inst", item_id: "test:wuji", item: %Item.ItemNotLoaded{}, meta: %{}}

          WorldItem.materialize_book(instance, book_item(%Book{skills: @wuji_skills}))
        end

      for r <- rolled do
        refute is_nil(r.meta.book.skill), "每个实例都必须掷出一个技能"
        refute is_nil(r.item.name), "每个实例都必须有随机标题"
        assert Enum.any?(@wuji_skills, &(&1.skill == r.meta.book.skill))
        assert Enum.any?(@wuji_skills, &(&1.name == r.item.name))
      end

      # 候选里的每支都至少被掷到过一次（随机性真的在动，不是固定取第一个）
      picked = rolled |> Enum.map(& &1.meta.book.skill) |> Enum.uniq() |> MapSet.new()
      assert MapSet.new(@wuji_skills |> Enum.map(& &1.skill)) == picked
    end

    test "只挂普通 book 时把共享书籍元数据拷进实例" do
      book = %Book{skill: "luohan-quan", min_skill: 0, max_skill: 99, exp_required: 10000, jing_cost: 30, difficulty: 25}
      instance = %Instance{id: "plain-inst", item_id: "test:book", item: %Item.ItemNotLoaded{}, meta: %{}}

      rolled = WorldItem.materialize_book(instance, book_item(book))

      assert rolled.meta.book == book
      # 普通书没有随机标题，实例字段原样不动（仍由共享定义 resolve 出名字）
      assert rolled.item == instance.item
      assert rolled.id == "plain-inst"
    end

    test "非书物品原样返回" do
      baozi = %Item{
        id: @real,
        name: "包子 Baozi",
        description: "一个热腾腾的包子。",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %{unit: "个"}
      }

      instance = %Instance{id: "baozi-inst", item_id: @real, item: %Item.ItemNotLoaded{}, meta: %{}}

      assert WorldItem.materialize_book(instance, baozi) == instance
    end

    test "定义缺失时原样返回不抛异常" do
      instance = %Instance{id: "gone-inst", item_id: @gone, item: %Item.ItemNotLoaded{}, meta: %{}}

      assert WorldItem.materialize_book(instance) == instance
    end
  end
end

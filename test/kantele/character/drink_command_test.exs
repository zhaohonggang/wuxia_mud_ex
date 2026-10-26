defmodule Kantele.Character.DrinkCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Verb
  alias Kantele.Character.DrinkCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @potion_id "test:potion"
  @nondrinkable_id "test:water"
  @wine_id "test:jiudai"
  @empty_id "test:emptybag"
  @noname_id "test:nonamebag"

  setup_all do
    Items.put(@potion_id, %Item{
      id: @potion_id,
      name: "疗伤药水",
      verbs: [%Verb{key: :drink, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{medicine: %{qi: 100, jing: 50}}
    })

    Items.put(@nondrinkable_id, %Item{
      id: @nondrinkable_id,
      name: "清水",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    # 容器液体（P3）：LPC `set("liquid", ([...]))`，喝的是容器余量而不是药效。
    # 注意容器路径**不看 verbs** —— LPC `drink.c` 只要求 `mapp(ob->query("liquid"))`。
    Items.put(@wine_id, %Item{
      id: @wine_id,
      name: "酒袋",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Kantele.World.Item.Meta{
        max_liquid: 15,
        liquid: %{type: "alcohol", name: "米酒", remaining: 2, drunk_apply: 3}
      }
    })

    Items.put(@empty_id, %Item{
      id: @empty_id,
      name: "空酒袋",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Kantele.World.Item.Meta{
        max_liquid: 15,
        liquid: %{type: "alcohol", name: "米酒", remaining: 0}
      }
    })

    # 没有液体名的容器（LPC 空容器分支「是空的」）
    Items.put(@noname_id, %Item{
      id: @noname_id,
      name: "水壶",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Kantele.World.Item.Meta{max_liquid: 5, liquid: %{type: "water", remaining: 0}}
    })

    :ok
  end

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_potion(qi \\ 4900, jing \\ 1900) do
    vitals = %Vitals{
      jing: jing,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: qi,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    potion_instance = %Kalevala.World.Item.Instance{
      id: "药水",
      item_id: @potion_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [potion_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_nondrinkable do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    water_instance = %Kalevala.World.Item.Instance{
      id: "清水",
      item_id: @nondrinkable_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [water_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_instance(item_id, instance_id, instance_meta \\ %{}) do
    instance = %Kalevala.World.Item.Instance{
      id: instance_id,
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: instance_meta
    }

    %{player() | inventory: [instance]}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "drink 命令" do
    test "身上没有可喝物品报错" do
      p = player()
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "药水"})
      text = output_text(conn)

      assert text =~ "你身上没有这样东西"
    end

    test "drink 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("drink 药水")
      assert parsed.module == DrinkCommand
    end

    test "heal 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("heal 药水")
      assert parsed.module == DrinkCommand
    end

    test "喝药水成功，气血精力恢复" do
      p = player_with_potion(4900, 1900)
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "药水"})
      text = output_text(conn)

      assert text =~ "你仰头喝下"
      assert text =~ "疗伤药水"
      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
    end

    test "不可饮用的物品报错" do
      p = player_with_nondrinkable()
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "清水"})
      text = output_text(conn)

      assert text =~ "可没法往嘴里灌"
    end
  end

  # ---- P3：容器液体（liquid / max_liquid 消费端，LPC cmds/std/drink.c） ----

  describe "drink 容器液体" do
    test "喝一口：余量减一，容器留在背包里（不消耗物品）" do
      p = player_with_instance(@wine_id, "bag-1")
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      updated = conn.private.update_character || conn.character
      assert [instance] = updated.inventory
      assert instance.meta["liquid_remaining"] == 1
      # 没喝完 → 不出现「喝得一滴也不剩」
      refute output_text(conn) =~ "一滴也不剩"
    end

    test "喝最后一口：余量归零并提示喝完" do
      p = player_with_instance(@wine_id, "bag-2", %{"liquid_remaining" => 1})
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      updated = conn.private.update_character || conn.character
      assert [instance] = updated.inventory
      assert instance.meta["liquid_remaining"] == 0
      assert output_text(conn) =~ "你已经将酒袋里的米酒喝得一滴也不剩了"
    end

    test "实例余量优先于定义（定义 2 口，实例只剩 3 → 喝到 2）" do
      p = player_with_instance(@wine_id, "bag-3", %{"liquid_remaining" => 3})
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      updated = conn.private.update_character || conn.character
      assert hd(updated.inventory).meta["liquid_remaining"] == 2
    end

    test "空容器：提示「已经被喝得一滴也不剩了」" do
      p = player_with_instance(@empty_id, "bag-4")
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "空酒袋"})

      assert output_text(conn) =~ "空酒袋里的米酒已经被喝得一滴也不剩了"
      # 余量不动
      updated = conn.private.update_character || conn.character
      assert hd(updated.inventory).meta["liquid_remaining"] in [nil, 0]
    end

    test "空容器且无液体名：提示「是空的」" do
      p = player_with_instance(@noname_id, "bag-5")
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "水壶"})

      assert output_text(conn) =~ "水壶是空的"
    end

    test "容器优先于药效路径（同一件物品有 liquid 就不走 Effect.consume）" do
      p = player_with_instance(@wine_id, "bag-6")
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      # 药水路径会移除实例并输出「你仰头喝下」
      refute output_text(conn) =~ "你仰头喝下"
      updated = conn.private.update_character || conn.character
      assert length(updated.inventory) == 1
    end
  end

  describe "drink 醉酒（LPC condition/drunk）" do
    # LPC cmds/std/drink.c:
    #   case "alcohol": apply_condition("drunk", query_condition("drunk") + drunk_apply)
    test "喝米酒（type=alcohol）累加 drunk_apply 到醉度" do
      # @wine_id: remaining 2, drunk_apply 3 -> 喝一口剩 1（>0）→ 挂 3 点醉度
      p = player_with_instance(@wine_id, "bag-d1")
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert conn.session["conditions"]["drunk"]["duration"] == 3
    end

    test "已醉时再喝：醉度累加而不是覆盖" do
      p = player_with_instance(@wine_id, "bag-d2")
      conn = build_conn(p, %{"conditions" => %{"drunk" => %{"duration" => 10}}})

      conn = DrinkCommand.run(conn, %{"item_name" => "酒袋"})

      assert conn.session["conditions"]["drunk"]["duration"] == 13
    end

    test "LPC 怪癖：喝空的那一口不挂醉度（switch 在提前返回之后）" do
      # 剩 1 口：喝完 remaining=0 → LPC 走 `return 1` 提前返回，跳过 switch
      p = player_with_instance(@wine_id, "bag-d3", %{"liquid_remaining" => 1})
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert output_text(conn) =~ "喝得一滴也不剩"
      assert conn.session["conditions"] == nil
    end

    test "非酒类（清水）不挂醉度" do
      p = player_with_instance(@noname_id, "bag-d4", %{"liquid_remaining" => 3})
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "水壶"})

      assert conn.session["conditions"] == nil
    end

    test "drunk_apply 为 0 的酒不挂空醉度" do
      p = player_with_instance(@wine_id, "bag-d5", %{"liquid_drunk_apply" => 0})
      conn = DrinkCommand.run(build_conn(p), %{"item_name" => "酒袋"})

      assert conn.session["conditions"] == nil
    end
  end
end

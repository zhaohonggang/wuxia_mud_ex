defmodule Kantele.Character.HandCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.HandCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items

  setup do
    Items.put("test:sword", %Item{
      id: "test:sword",
      name: "长剑",
      verbs: [],
      callback_module: Item,
      meta: %Kantele.World.Item.Meta{weight: 1000, unit: "把", flag: 1, damage: 10}
    })

    Items.put("test:heavy", %Item{
      id: "test:heavy",
      name: "巨石",
      verbs: [],
      callback_module: Item,
      meta: %Kantele.World.Item.Meta{weight: 50_000, unit: "块", flag: 1}
    })

    Items.put("test:greatsword", %Item{
      id: "test:greatsword",
      name: "巨剑",
      verbs: [],
      callback_module: Item,
      meta: %Kantele.World.Item.Meta{weight: 4000, unit: "把", flag: 4, damage: 20}
    })

    Items.put("test:dagger", %Item{
      id: "test:dagger",
      name: "匕首",
      verbs: [],
      callback_module: Item,
      meta: %Kantele.World.Item.Meta{weight: 200, unit: "把", flag: 2, damage: 5}
    })

    :ok
  end

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp instance(item_id) do
    %Item.Instance{id: "inst-" <> item_id, item_id: item_id, created_at: DateTime.utc_now()}
  end

  defp with_handing(character, item_name) do
    equipped = Map.put(character.meta.combat.equipped, :handing, %{name: item_name})
    combat = %{character.meta.combat | equipped: equipped}
    %{character | meta: %{character.meta | combat: combat}}
  end

  defp equipped_in_slot(character, slot, item_name, flag \\ nil) do
    snapshot = if flag, do: %{name: item_name, flag: flag}, else: %{name: item_name}
    equipped = Map.put(character.meta.combat.equipped, slot, snapshot)
    combat = %{character.meta.combat | equipped: equipped}
    %{character | meta: %{character.meta | combat: combat}}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "hand 命令门控" do
    test "无参数时提示指令格式" do
      p = player()
      conn = HandCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "指令格式"
      assert output_text(conn) =~ "hand"
    end

    test "hand nothing，空手时提示" do
      p = player()
      conn = HandCommand.run(build_conn(p), %{"rest" => "nothing"})
      assert output_text(conn) =~ "本来就什么都没有拿"
    end

    test "hand none，空手时提示" do
      p = player()
      conn = HandCommand.run(build_conn(p), %{"rest" => "none"})
      assert output_text(conn) =~ "本来就什么都没有拿"
    end

    test "背包中无此物品" do
      p = player()
      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})
      assert output_text(conn) =~ "你的身上没有这样东西"
    end

    test "已持同一物品时提示" do
      p = %{player() | inventory: [instance("test:sword")]} |> with_handing("长剑")
      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})
      assert output_text(conn) =~ "你不是正拿着长剑吗"
    end

    test "手持过重物品被拒绝" do
      p = player(inventory: [instance("test:heavy")])
      conn = HandCommand.run(build_conn(p), %{"rest" => "巨石"})
      assert output_text(conn) =~ "太重了，你单手拿不住"
    end

    test "主手武器为双手时无法再手持" do
      p = player(inventory: [instance("test:sword")]) |> equipped_in_slot(:weapon, "巨剑", 4)
      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})
      assert output_text(conn) =~ "双手都拿着武器"
    end

    test "主手单手武器并已有副手武器时无法再手持" do
      p =
        player(inventory: [instance("test:sword")])
        |> equipped_in_slot(:weapon, "匕首", 1)
        |> equipped_in_slot(:secondary_weapon, "短剑")

      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})
      assert output_text(conn) =~ "双手都拿着武器"
    end

    test "物品已装备时无法手持" do
      p = player(inventory: [instance("test:sword")]) |>
           equipped_in_slot(:cloth, "长剑")
      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})
      assert output_text(conn) =~ "你正装备着长剑呢"
    end
  end

  describe "hand 命令执行" do
    test "hand nothing 收回已持物品并清空 handing 槽位" do
      p = player(inventory: [instance("test:sword")]) |> with_handing("长剑")
      conn = HandCommand.run(build_conn(p), %{"rest" => "nothing"})

      assert output_text(conn) =~ "收回包囊"
      assert output_text(conn) =~ "长剑"

      updated = conn.private.update_character || conn.character
      assert is_nil(Map.get(updated.meta.combat.equipped, :handing))
    end

    test "hand none 收回已持物品并清空 handing 槽位" do
      p = player(inventory: [instance("test:sword")]) |> with_handing("长剑")
      conn = HandCommand.run(build_conn(p), %{"rest" => "none"})

      updated = conn.private.update_character || conn.character
      assert is_nil(Map.get(updated.meta.combat.equipped, :handing))
    end

    test "手持背包物品：设定 handing 槽位并输出文案" do
      p = player(inventory: [instance("test:sword")])
      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})

      assert output_text(conn) =~ "握在手中"
      assert output_text(conn) =~ "长剑"

      updated = conn.private.update_character || conn.character
      holding = Map.get(updated.meta.combat.equipped, :handing)
      assert holding == %{name: "长剑"}
    end

    test "先持别的物品再手持新物品：收回旧物后持新物" do
      p = player() |> with_handing("巨石")
      p = %{p | inventory: [instance("test:heavy"), instance("test:sword") | p.inventory]}

      conn = HandCommand.run(build_conn(p), %{"rest" => "长剑"})

      text = output_text(conn)
      assert text =~ "收回手中的巨石"
      assert text =~ "握在手中"

      updated = conn.private.update_character || conn.character
      holding = Map.get(updated.meta.combat.equipped, :handing)
      assert holding == %{name: "长剑"}
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("hand 剑")
      assert parsed.module == HandCommand
    end
  end
end

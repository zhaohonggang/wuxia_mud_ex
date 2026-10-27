defmodule Kantele.Character.FuseCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.Combat
  alias Kantele.Character.FuseCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  # 5 灵石（clone_lib zone）。value 取 LPC 原 base_value。
  # 注入到 Items 注册表，使 compute_magic_points 能取到 value。
  @stones [
    {"clone_lib:fam_item_stone1", "炽石 Chishi", 30_000},
    {"clone_lib:fam_item_stone2", "岚石 Lanshi", 50_000},
    {"clone_lib:fam_item_stone3", "皓石 Haoshi", 100_000},
    {"clone_lib:fam_item_stone4", "辉石 Huishi", 180_000},
    {"clone_lib:fam_item_stone5", "辉月华石 Huiyuehuashi", 500_000}
  ]

  @all_stones Enum.map(@stones, fn {id, _, _} -> id end)

  setup do
    # 原料：name 含中文；matches? 用「中文前缀 + 空格」命中
    Items.put("fuse:xuantie", %Item{
      id: "fuse:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{can_make: "all", item_origin: 1, power_point: 100}
    })

    Items.put("fuse:zijin", %Item{
      id: "fuse:zijin",
      name: "紫金 Zijin",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{can_make: ["甲"], item_origin: 1, power_point: 50}
    })

    Items.put("fuse:low", %Item{
      id: "fuse:low",
      name: "玄晶 Xuanjing",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{can_make: "all", item_origin: 1, power_point: 30}
    })

    Items.put("fuse:plain", %Item{
      id: "fuse:plain",
      name: "废铁 Feitie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{power_point: 100}
    })

    for {id, name, value} <- @stones do
      Items.put(id, %Item{
        id: id,
        name: name,
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{value: value, weight: 100, unit: "颗", material: "stone"}
      })
    end

    :ok
  end

  defp player(inventory, opts \\ []) do
    force = Keyword.get(opts, :force, 300)
    max_neili = Keyword.get(opts, :max_neili, 5000)
    neili = Keyword.get(opts, :neili, 3000)

    vitals = struct(Vitals.new(), max_neili: max_neili, neili: neili)
    stats = struct(Stats.new(), skills: %{"force" => force})

    combat =
      case Keyword.get(opts, :combat) do
        nil -> Combat.new()
        c -> c
      end

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      attributes: Keyword.get(opts, :attributes, %{}),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  defp updated_character(conn), do: conn.private.update_character || conn.character

  defp updated_inventory(conn), do: updated_character(conn).inventory
  defp updated_attributes(conn), do: updated_character(conn).attributes
  defp updated_combat(conn), do: updated_character(conn).meta.combat

  describe "路由与空参数" do
    test "空参数提示（rest 为空）" do
      conn = FuseCommand.run(build_conn(player([])), %{"rest" => ""})
      assert output_text(conn) =~ "你要熔炼什么物品？"
    end

    test "无 arg 键走 run(%{})" do
      conn = FuseCommand.run(build_conn(player([])), %{})
      assert output_text(conn) =~ "你要熔炼什么物品？"
    end

    test "路由解析：reminder 落在 params[\"rest\"]" do
      {:ok, parsed} = Kantele.Character.Commands.parse("fuse 玄铁")
      assert parsed.module == FuseCommand
      assert parsed.function == :run
      assert parsed.params["rest"] == "玄铁"
    end
  end

  describe "状态拦截" do
    test "busy 中拒绝" do
      p = player([], combat: %{Combat.new() | busy: 1})
      conn = FuseCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "先忙完了你的事情再做这件事情吧。"
    end

    test "战斗中拒绝" do
      p = player([], combat: %{Combat.new() | enemies: [%{id: "e1"}]})
      conn = FuseCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "你现在正在打架，没时间做这些事情。"
    end
  end

  describe "内功/内力门槛" do
    test "内功 < 300 拒绝" do
      p = player([instance("fuse:xuantie")], force: 10)
      conn = FuseCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "你的内功修为不够"
    end

    test "最大内力 < 5000 拒绝" do
      p = player([instance("fuse:xuantie")], max_neili: 200)
      conn = FuseCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "你的内力修为不够"
    end

    test "当前内力 < 3000 拒绝" do
      p = player([instance("fuse:xuantie")], neili: 200)
      conn = FuseCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "你现在的内力不足"
    end
  end

  describe "物品查找与条件" do
    test "身上没有该物品" do
      p = player([instance("fuse:zijin")])
      conn = FuseCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "你身上没有这件物品。"
    end

    test "缺少 can_make / item_origin 时拒绝且不消耗" do
      p = player([instance("fuse:plain")])
      conn = FuseCommand.run(build_conn(p), %{"rest" => "废铁"})
      assert output_text(conn) =~ "这东西似乎熔炼不出什么。"
      assert updated_inventory(conn) |> Enum.map(& &1.item_id) == ["fuse:plain"]
    end
  end

  describe "熔炼成功（随机性无关断言）" do
    test "玄铁熔炼：原料出包、灵石入包、灵慧一致、内力消耗、busy" do
      conn = FuseCommand.run(build_conn(player([instance("fuse:xuantie")])), %{"rest" => "玄铁"})

      item_ids = updated_inventory(conn) |> Enum.map(& &1.item_id)
      assert "fuse:xuantie" not in item_ids
      stones = Enum.filter(item_ids, &(&1 in @all_stones))
      assert length(stones) == 1

      # 灵慧消息与 attributes["magic_points"] 一致（stone value>0 → mp>0）
      text = output_text(conn)
      assert Regex.match?(~r/你通过熔炼玄铁 Xuantie的过程，从而获得了\d+点灵慧。/, text)
      [_, mp_str] = Regex.run(~r/从而获得了(\d+)点灵慧。/, text)
      assert updated_attributes(conn)["magic_points"] == String.to_integer(mp_str)

      vitals = updated_character(conn).meta.vitals
      assert vitals.max_neili == 4999
      assert vitals.neili == 0
      assert Combat.busy?(updated_combat(conn))
    end

    test "低 power_point (<50) → 化作青烟、不留任何东西、仍耗内力 + busy" do
      conn = FuseCommand.run(build_conn(player([instance("fuse:low")])), %{"rest" => "玄晶"})

      item_ids = updated_inventory(conn) |> Enum.map(& &1.item_id)
      assert "fuse:low" not in item_ids
      refute Enum.any?(item_ids, &(&1 in @all_stones))

      assert updated_attributes(conn)["magic_points"] == nil
      vitals = updated_character(conn).meta.vitals
      assert vitals.max_neili == 4999
      assert vitals.neili == 0
      assert Combat.busy?(updated_combat(conn))
    end
  end
end

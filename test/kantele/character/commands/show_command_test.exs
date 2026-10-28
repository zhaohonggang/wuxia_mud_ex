defmodule Kantele.Character.ShowCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.ShowCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  setup do
    # 锻造原料：name 含中文，matches? 用「中文前缀 + 空格」命中（与 fuse 测试同款）
    Items.put("show:xuantie", %Item{
      id: "show:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{material_attrib: "steel", material_name: "玄铁", power_point: 100}
    })

    # 已耗尽（有 material_attrib 但 power_point 为 0）→ 锻造不了了
    Items.put("show:depleted", %Item{
      id: "show:depleted",
      name: "残铁 Cantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{material_attrib: "silk", material_name: "残铁", power_point: 0}
    })

    # 普通物品：无 material_attrib → 没听说过
    Items.put("show:plain", %Item{
      id: "show:plain",
      name: "废铁 Feitie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{power_point: 100}
    })

    :ok
  end

  defp player(inventory) do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{})

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      attributes: %{},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats
      }
    }
  end

  defp instance(item_id, id \\ nil) do
    %Instance{
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

  describe "路由与空参数" do
    test "空参数提示" do
      conn = ShowCommand.run(build_conn(player([])), %{"rest" => ""})
      assert output_text(conn) =~ "你想干什么呢？"
    end

    test "无 arg 键走 run(%{})" do
      conn = ShowCommand.run(build_conn(player([])), %{})
      assert output_text(conn) =~ "你想干什么呢？"
    end

    test "路由解析：show 落在 ShowCommand，参数落 params[\"rest\"]" do
      {:ok, parsed} = Kantele.Character.Commands.parse("show 玄铁")
      assert parsed.module == ShowCommand
      assert parsed.function == :run
      assert parsed.params["rest"] == "玄铁"
    end
  end

  describe "物品查找与三路估价" do
    test "身上没有该物品" do
      p = player([instance("show:depleted")])
      conn = ShowCommand.run(build_conn(p), %{"rest" => "玄铁"})
      assert output_text(conn) =~ "算了吧，你身上没有 玄铁 这种东西。"
    end

    test "无 material_attrib → 没听说过" do
      p = player([instance("show:plain")])
      conn = ShowCommand.run(build_conn(p), %{"rest" => "废铁"})
      assert output_text(conn) =~ "莫邪对你说道：这种东西也能用来炼制，我没听说过。"
    end

    test "power_point 为 0 → 锻造不了了" do
      p = player([instance("show:depleted")])
      conn = ShowCommand.run(build_conn(p), %{"rest" => "残铁"})
      assert output_text(conn) =~ "莫邪对你说道：这样原料看来已经是锻造不了了。"
    end

    test "正常原料 → 估价 = power_point*2 + 20" do
      p = player([instance("show:xuantie")])
      conn = ShowCommand.run(build_conn(p), %{"rest" => "玄铁"})
      text = output_text(conn)
      assert text =~ "莫邪对你说道：这种原料打造道具，只需要 220 两黄金。"
      assert text =~ "要是没有问题，请给我原料并付钱。"
    end
  end
end

defmodule Kantele.Character.ForgeCustomizeCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.World.Items
  alias Kantele.World.Item
  alias Kantele.World.Item.Meta
  alias Kantele.Character.ForgeCustomizeCommand

  @owner_id "player-forge-custom-1"
  @owner_name "孙七"

  setup do
    Forging.ensure_table()
    Forging.delete(@owner_id)

    Items.put("forge:xuantie", %ItemDef{
      id: "forge:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Item,
      meta: %Meta{
        material_attrib: "steel",
        material_name: "玄铁",
        power_point: 100,
        weight: 500,
        can_make: "all",
        not_make: nil
      }
    })

    on_exit fn ->
      # 清理 S3 测试生成的动态模板与 JSON
      item_id = "forge:#{@owner_id}-xuantiejian"
      Items.delete(item_id)
      path = Path.join("data/forge", "#{item_id}.json")
      if File.regular?(path), do: File.rm(path)
    end

    :ok
  end

  defp player() do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{"force" => 50})

    %Character{
      id: @owner_id,
      name: @owner_name,
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp session(extra \\ %{}) do
    %{
      status: "inputing",
      can_help: true,
      point: 100,
      owner_id: @owner_id,
      owner_name: @owner_name,
      ctype: "剑",
      stype: "sword",
      unit: "柄",
      wscale: 150,
      material_item_id: "forge:xuantie",
      material_instance_id: "inst-xuantie",
      value: 220
    }
    |> Map.merge(Map.new(extra))
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  describe "路由解析" do
    test "name/desc/wieldmsg/unwieldmsg/finish/完成 皆落在 ForgeCustomizeCommand" do
      {:ok, parsed} = Kantele.Character.Commands.parse("name 玄铁剑 xuantiejian")
      assert parsed.module == ForgeCustomizeCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("desc 一把锋利的剑")
      assert parsed.module == ForgeCustomizeCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("wieldmsg 你装备上了剑")
      assert parsed.module == ForgeCustomizeCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("unwieldmsg 你收起了剑")
      assert parsed.module == ForgeCustomizeCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("finish")
      assert parsed.module == ForgeCustomizeCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("完成")
      assert parsed.module == ForgeCustomizeCommand
    end
  end

  describe "name 定型" do
    test "设定名称与代号，会话字段已填" do
      Forging.put(@owner_id, session())
      conn = ForgeCustomizeCommand.run_name(build_conn(player()), %{"rest" => "玄铁剑 xuantiejian"})

      s = Forging.get(@owner_id)
      assert s.name == "玄铁剑"
      assert s.sid == "xuantiejian"

      assert output_text(conn) =~ "已记下武器名称"
      assert output_text(conn) =~ "玄铁剑"
      assert output_text(conn) =~ "xuantiejian"
    end

    test "参数不足 → 提示格式" do
      Forging.put(@owner_id, session())
      conn = ForgeCustomizeCommand.run_name(build_conn(player()), %{"rest" => "玄铁剑"})

      assert output_text(conn) =~ "格式：name"
    end

    test "非法代号（含特殊字符）→ 拒绝" do
      Forging.put(@owner_id, session())
      conn = ForgeCustomizeCommand.run_name(build_conn(player()), %{"rest" => "玄铁剑 xuantie-jian"})

      assert output_text(conn) =~ "只能用字母、数字和下划线"
    end

    test "代号已被占用 → 拒绝" do
      # 先注册一个同 item_id 的模板，模拟占用
      occupied = "forge:#{@owner_id}-taken"
      Items.put(occupied, %ItemDef{id: occupied, name: "占用", meta: %Meta{}})

      Forging.put(@owner_id, session(%{sid: "taken"}))
      conn = ForgeCustomizeCommand.run_name(build_conn(player()), %{"rest" => "测试剑 taken"})

      assert output_text(conn) =~ "已被占用"
      Items.delete(occupied)
    end
  end

  describe "desc/wieldmsg/unwieldmsg 定型" do
    test "desc 设定描述" do
      Forging.put(@owner_id, session(%{name: "玄铁剑", sid: "xuantiejian"}))
      conn = ForgeCustomizeCommand.run_desc(build_conn(player()), %{"rest" => "一把由玄铁炼制的利剑，寒光四射。"})

      s = Forging.get(@owner_id)
      assert s.long == "一把由玄铁炼制的利剑，寒光四射。"

      assert output_text(conn) =~ "已记下武器描述"
    end

    test "wieldmsg 设定装备文案" do
      Forging.put(@owner_id, session(%{name: "玄铁剑", sid: "xuantiejian"}))
      conn = ForgeCustomizeCommand.run_wieldmsg(build_conn(player()), %{"rest" => "你腰间悬起玄铁剑"})

      s = Forging.get(@owner_id)
      assert s.wield_msg == "你腰间悬起玄铁剑"

      assert output_text(conn) =~ "已记下装备文案"
    end

    test "unwieldmsg 设定收起文案" do
      Forging.put(@owner_id, session(%{name: "玄铁剑", sid: "xuantiejian"}))
      conn = ForgeCustomizeCommand.run_unwieldmsg(build_conn(player()), %{"rest" => "你将剑收回鞘中"})

      s = Forging.get(@owner_id)
      assert s.unwield_msg == "你将剑收回鞘中"

      assert output_text(conn) =~ "已记下收起文案"
    end
  end

  describe "finish 生成物品" do
    test "走完全流程：ETS 注册 + JSON 落盘 + 实例入包 + 会话清" do
      Forging.put(@owner_id, session(%{
        name: "玄铁剑",
        sid: "xuantiejian",
        long: "一把由玄铁炼制的利剑。",
        wield_msg: "你腰间悬起了玄铁剑。",
        unwield_msg: "你将玄铁剑收回鞘中。"
      }))

      item_id = "forge:#{@owner_id}-xuantiejian"

      conn = ForgeCustomizeCommand.run_finish(build_conn(player()), %{})

      # ETS 注册
      assert Items.get(item_id) != {:error, :not_found}

      # JSON 落盘
      path = Path.join("data/forge", "#{item_id}.json")
      assert File.regular?(path)
      content = File.read!(path)
      assert content =~ "玄铁剑"
      assert content =~ "xuantiejian"

      # 实例入背包
      c = updated_char(conn)
      assert Enum.any?(c.inventory, &(&1.item_id == item_id))

      # 会话清
      assert Forging.get(@owner_id) == nil

      # 输出文案
      assert output_text(conn) =~ "交给了你"
      assert output_text(conn) =~ "锻造完成"
    end

    test "未起名 → finish 被拒绝" do
      Forging.put(@owner_id, session(%{name: nil, sid: nil}))
      conn = ForgeCustomizeCommand.run_finish(build_conn(player()), %{})

      assert output_text(conn) =~ "尚未起名"
      assert Forging.get(@owner_id) != nil
    end

    test "裸 finish（无 rest 参数）→ 生成物品" do
      Forging.put(@owner_id, session(%{
        name: "玄铁剑",
        sid: "xuantiejian2"
      }))

      item_id = "forge:#{@owner_id}-xuantiejian2"

      conn = ForgeCustomizeCommand.run_finish(build_conn(player()), %{})

      assert Items.get(item_id) != {:error, :not_found}
      c = updated_char(conn)
      assert Enum.any?(c.inventory, &(&1.item_id == item_id))
      assert Forging.get(@owner_id) == nil

      Items.delete(item_id)
      path = Path.join("data/forge", "#{item_id}.json")
      if File.regular?(path), do: File.rm(path)
    end
  end

  describe "会话门控" do
    test "无活跃会话 → 拒绝" do
      Forging.delete(@owner_id)
      conn = ForgeCustomizeCommand.run_name(build_conn(player()), %{"rest" => "玄铁剑 xuantiejian"})

      assert output_text(conn) =~ "没有进行中的锻造会话"
    end

    test "status != inputing → 拒绝" do
      Forging.put(@owner_id, session(%{status: "handoff"}))
      conn = ForgeCustomizeCommand.run_name(build_conn(player()), %{"rest" => "玄铁剑 xuantiejian"})

      assert output_text(conn) =~ "炉火尚未备好"
      s = Forging.get(@owner_id)
      assert s.status == "handoff"
    end
  end
end

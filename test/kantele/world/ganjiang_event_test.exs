defmodule Kantele.World.GanjiangEventTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kantele.Character.GanjiangEvent
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @owner_id "player-gan-1"
  @owner_name "王五"

  setup do
    Forging.ensure_table()
    Forging.delete(@owner_id)

    Items.put("forge:xuantie", %Item{
      id: "forge:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{material_attrib: "steel", material_name: "玄铁", power_point: 100}
    })

    :ok
  end

  defp ganjiang do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{})

    %Character{
      id: "ganjiang",
      name: "干将 Ganjiang",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp session(extra \\ %{}) do
    %{
      status: "handoff",
      value: 220,
      material_item_id: "forge:xuantie",
      material_instance_id: "inst-xuantie",
      owner_id: @owner_id,
      owner_name: @owner_name,
      types: ["剑"],
      ctype: "剑",
      stype: "sword",
      unit: "柄",
      point: 100,
      prop: 0,
      wscale: 150
    }
    |> Map.merge(extra)
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "干将接收 forge/handoff" do
    test "材料入包、status=inputing、can_help、making_instance_id、6 段 vision 不崩溃" do
      Forging.put(@owner_id, session())
      inst = %Instance{id: "inst-xuantie", item_id: "forge:xuantie"}
      event = event(ganjiang(), "forge/handoff", %{
        material_instance: inst,
        session: session()
      })

      conn = GanjiangEvent.handoff(build_conn(ganjiang()), event)

      # 会话进入 inputing
      s = Forging.get(@owner_id)
      assert s.status == "inputing"
      assert s.can_help == true
      assert s.making_instance_id == "inst-xuantie"

      # 材料计入干将背包
      updated = conn.private.update_character || conn.character
      assert Enum.any?(updated.inventory, &(&1.id == "inst-xuantie"))

      # 连续再次调用幂等（再次 handoff 仍可进行）
      conn2 = build_conn(updated)
      conn2 = GanjiangEvent.handoff(conn2, event)
      s2 = Forging.get(@owner_id)
      assert s2.status == "inputing"
    end
  end

  describe "输出不崩溃" do
    test "handoff 不向玩家 conn 输出文本（vision 经房间广播，非 conn.output）" do
      Forging.put(@owner_id, session())
      inst = %Instance{id: "inst-xuantie", item_id: "forge:xuantie"}
      event = event(ganjiang(), "forge/handoff", %{material_instance: inst, session: session()})

      conn = GanjiangEvent.handoff(build_conn(ganjiang()), event)
      assert output_text(conn) == ""
    end
  end
end

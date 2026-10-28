defmodule Kantele.World.ForgingAnswerTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kantele.World.ForgingAnswer
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items
  alias Kantele.Character.AnswerCommand

  @from_id "player-forge-1"
  @from_name "李四"

  setup do
    Forging.ensure_table()
    Forging.delete(@from_id)

    Items.put("forge:xuantie", %Item{
      id: "forge:xuantie",
      name: "玄铁 Xuantie",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{
        material_attrib: "steel",
        material_name: "玄铁",
        power_point: 100,
        can_make: "all",
        not_make: nil
      }
    })

    Items.put("forge:gold", %Item{
      id: "forge:gold",
      name: "黄金 Gold",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Meta{}
    })

    :ok
  end

  defp moye do
    %Character{
      id: "moye",
      name: "莫邪 Moye",
      pid: self(),
      room_id: "test:room",
      inventory: [%Instance{id: "inst-xuantie", item_id: "forge:xuantie"}],
      attributes: %{},
      meta: %{accept: [%{kind: "forge"}]}
    }
  end

  defp player(id \\ @from_id, name \\ @from_name, inventory \\ []) do
    vitals = struct(Vitals.new())
    stats = struct(Stats.new(), skills: %{})

    %Character{
      id: id,
      name: name,
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp session do
    %{
      status: "answer_type",
      # 220 两黄金 → 记账单位是文
      value: 2_200_000,
      material_item_id: "forge:xuantie",
      material_instance_id: "inst-xuantie",
      owner_id: @from_id,
      owner_name: @from_name,
      types: ["剑", "刀"],
      money_instance_id: "inst-gold",
      money_instance: %Instance{id: "inst-gold", item_id: "forge:gold"}
    }
  end

  defp answer_event(type, opts \\ []) do
    %{data:
      Map.merge(
        %{type: type, from_id: @from_id, from_name: @from_name, reply_to: self()},
        Enum.into(opts, %{})
      )}
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

  describe "合法类型 + 干将在场（handoff）" do
    test "填类型字段、材料转交干将、发 forge/handoff" do
      Forging.put(@from_id, session())
      event = answer_event("剑")

      conn = ForgingAnswer.answer(build_conn(moye()), moye(), event, ganjiang_pid: self())

      # 会话推进到 handoff，字段已填
      s = Forging.get(@from_id)
      assert s.status == "handoff"
      assert s.ctype == "剑"
      assert s.stype == "sword"
      assert s.unit == "柄"
      assert s.point == 100
      assert s.wscale == 150
      assert s.owner_id == @from_id

      # 莫邪背包已移除材料
      refute Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))

      # 干将收到 handoff 事件
      assert_receive %Kalevala.Event{topic: "forge/handoff", data: data}, 500
      assert data.material_instance.id == "inst-xuantie"
      assert data.session.ctype == "剑"
      assert data.from_id == @from_id
    end
  end

  describe "合法类型 + 干将不在（refund）" do
    test "退材料 + 退钱，清会话，发 forge/refund 给玩家" do
      Forging.put(@from_id, session())
      event = answer_event("刀")

      conn = ForgingAnswer.answer(build_conn(moye()), moye(), event)

      # 会话被清除
      assert Forging.get(@from_id) == nil
      # 莫邪背包已移除材料
      refute Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))

      # 玩家收到退款事件（材料 + 钱币实例）
      assert_receive %Kalevala.Event{topic: "forge/refund", data: data}, 500
      assert data.material_instance.id == "inst-xuantie"
      assert data.money_instance.id == "inst-gold"
    end
  end

  describe "非法类型 / 状态不符" do
    test "类型不在允许列表 → 会话不变、不退材料、无事件" do
      Forging.put(@from_id, session())
      event = answer_event("靴子")

      conn = ForgingAnswer.answer(build_conn(moye()), moye(), event)

      s = Forging.get(@from_id)
      assert s.status == "answer_type"
      assert Enum.any?(updated_char(conn).inventory, &(&1.id == "inst-xuantie"))

      refute_receive %Kalevala.Event{topic: "forge/handoff"}, 100
      refute_receive %Kalevala.Event{topic: "forge/refund"}, 100
    end

    test "无活跃会话 → 直接返回，不做任何处理" do
      Forging.delete(@from_id)
      event = answer_event("剑", ganjiang_pid: self())

      conn = ForgingAnswer.answer(build_conn(moye()), moye(), event)

      assert conn.character == moye()
      assert Forging.get(@from_id) == nil
    end
  end

  describe "AnswerCommand 路由" do
    test "answer <类型> 解析到 AnswerCommand，参数落 params[\"rest\"]" do
      {:ok, parsed} = Kantele.Character.Commands.parse("answer 剑")
      assert parsed.module == AnswerCommand
      assert parsed.params["rest"] == "剑"
    end

    test "裸 answer 解析无 rest" do
      {:ok, parsed} = Kantele.Character.Commands.parse("answer")
      assert parsed.module == AnswerCommand
      refute Map.has_key?(parsed.params, "rest")
    end

    test "无 forge 会话 → 原 stub「回答系统暂未开放。」" do
      Forging.delete(@from_id)
      conn = AnswerCommand.run(build_conn(player()), %{"rest" => "剑"})
      assert output_text(conn) =~ "回答系统暂未开放。"
    end

    test "裸 answer 无 forge 会话 → 「你要回答什么？」" do
      Forging.delete(@from_id)
      conn = AnswerCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "你要回答什么？"
    end
  end
end

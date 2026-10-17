defmodule Kantele.World.RoomActions.MoveHandlersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActionDispatcher
  alias Kantele.World.RoomActions.Lingxiao.Juegu.Pan

  defp room_with_actions(actions) do
    %Room{id: "z:r", key: "r", zone_id: "z", actions: actions}
  end

  # 两个契约探针：一个声明「本次不处理」（LPC return 0），一个原样返回。
  defmodule AlwaysNotHandled do
    use Kantele.World.RoomAction
    def run(_conn, _params), do: :not_handled
  end

  defmodule EchoHandler do
    use Kantele.World.RoomAction
    def run(conn, _params), do: conn
  end

  # 真实 Conn/Character/Private：Teleport.teleport/2 需要 events / channel_changes
  # 都是真字段才能走通（move/2、subscribe/4 都是纯结构体操作）。
  # MoveView 会渲染 CharacterView.render("name")，它读 id / name / description 三个字段。
  defp conn_in(room_id, actions) do
    %Conn{
      character: %Kalevala.Character{
        id: "c1",
        name: "测试",
        description: "测试角色",
        room_id: room_id
      },
      private: %Private{room: room_with_actions(actions), channel_changes: []},
      output: [],
      events: []
    }
  end

  defp dispatch(conn, text) do
    RoomActionDispatcher.dispatch(conn, text, &RoomActionHandlers.lookup/2)
  end

  defp movements(conn) do
    conn.events
    |> Enum.filter(&match?(%Event{topic: Movement}, &1))
    |> Enum.map(fn %Event{data: %Movement{direction: dir, room_id: rid}} -> {dir, rid} end)
  end

  defp texts(conn) do
    Enum.flat_map(conn.output, fn
      %Text{data: data} -> [data]
      _ -> []
    end)
  end

  defp publishes(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:publish, _c, _e, _o, _f}, &1))
    |> Enum.map(fn {:publish, channel, event, _opts, _err} -> {channel, event.data.text} end)
  end

  defp subscriptions(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:subscribe, _c, _o, _f}, &1))
    |> Enum.map(fn {:subscribe, channel, _opts, _err} -> channel end)
  end

  defp unsubscriptions(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(&match?({:unsubscribe, _c, _o, _f}, &1))
    |> Enum.map(fn {:unsubscribe, channel, _opts, _err} -> channel end)
  end

  describe "lingxiao:juegu do_pan（climb 纯位移）" do
    test "注册表认得该房间的 do_pan" do
      assert {:ok, {Pan, :run}} = RoomActionHandlers.lookup("lingxiao:juegu", "do_pan")
    end

    test "climb → 瞬移到 lingxiao:shiya，且不带任何文案" do
      conn = conn_in("lingxiao:juegu", %{"climb" => "do_pan"})

      assert {:handled, conn2} = dispatch(conn, "climb")

      assert conn2.private.update_character.room_id == "lingxiao:shiya"
      assert movements(conn2) == [{:from, "lingxiao:juegu"}, {:to, "lingxiao:shiya"}]
      assert texts(conn2) == []
      assert publishes(conn2) == []
    end

    test "换房间：退订旧房间、订阅新房间、并触发一次 room/look" do
      conn = conn_in("lingxiao:juegu", %{"climb" => "do_pan"})

      assert {:handled, conn2} = dispatch(conn, "climb")

      assert unsubscriptions(conn2) == ["rooms:lingxiao:juegu"]
      assert subscriptions(conn2) == ["rooms:lingxiao:shiya"]
      assert Enum.any?(conn2.events, &match?(%Event{topic: "room/look"}, &1))
    end
  end

  describe "hengyang:furong1 do_climb（参数 stone 校验）" do
    test "参数为 stone → 提示 + 瞬移到 furongfeng" do
      conn = conn_in("hengyang:furong1", %{"climb" => "do_climb"})

      assert {:handled, conn2} = dispatch(conn, "climb stone")

      assert Enum.any?(texts(conn2), &String.contains?(&1, "爬出了洞口"))
      assert conn2.private.update_character.room_id == "hengyang:furongfeng"
    end

    test "参数不是 stone → 只提示，不移动" do
      conn = conn_in("hengyang:furong1", %{"climb" => "do_climb"})

      assert {:handled, conn2} = dispatch(conn, "climb tree")

      assert texts(conn2) == ["你想爬什么？\n"]
      assert movements(conn2) == []
      assert is_nil(conn2.private.update_character)
    end

    test "无参数 → 同样只提示（LPC `!arg`）" do
      conn = conn_in("hengyang:furong1", %{"climb" => "do_climb"})

      assert {:handled, conn2} = dispatch(conn, "climb")

      assert texts(conn2) == ["你想爬什么？\n"]
      assert movements(conn2) == []
    end
  end

  describe "changan:kzsleep do_bed（move 前后各一次广播）" do
    test "bed → 旧房间广播「准备上床」，新房间广播「钻了进来」" do
      conn = conn_in("changan:kzsleep", %{"bed" => "do_bed"})

      assert {:handled, conn2} = dispatch(conn, "bed")

      assert publishes(conn2) == [
               {"rooms:changan:kzsleep", "测试掀开纱帐，准备上床了。\n\n"},
               {"rooms:changan:bed", "\n沙帐轻轻一动，测试钻了进来。\n"}
             ]

      assert conn2.private.update_character.room_id == "changan:bed"
    end

    test "广播顺序：旧房间 → 退订 → 订阅新房间 → 新房间（与 LPC 一致）" do
      conn = conn_in("changan:kzsleep", %{"bed" => "do_bed"})

      assert {:handled, conn2} = dispatch(conn, "bed")

      # channel_changes 内部是「前插」，handle_channels 会 reverse 回时序
      order =
        conn2.private.channel_changes
        |> Enum.reverse()
        |> Enum.map(fn
          {:publish, channel, _e, _o, _f} -> {:publish, channel}
          {:subscribe, channel, _o, _f} -> {:subscribe, channel}
          {:unsubscribe, channel, _o, _f} -> {:unsubscribe, channel}
          other -> other
        end)

      assert order == [
               {:publish, "rooms:changan:kzsleep"},
               {:unsubscribe, "rooms:changan:kzsleep"},
               {:subscribe, "rooms:changan:bed"},
               {:publish, "rooms:changan:bed"}
             ]
    end
  end

  describe "xiakedao:xiaowu do_move（arg 校验 + return 0 语义）" do
    test "参数为 bed → 旧房间广播、瞬移、本人补一句" do
      conn = conn_in("xiakedao:xiaowu", %{"move" => "do_move"})

      assert {:handled, conn2} = dispatch(conn, "move bed")

      assert publishes(conn2) == [
               {"rooms:xiakedao:xiaowu", "测试用力把小床移开，发现里面竟然有一条秘密通道！\n"}
             ]

      assert conn2.private.update_character.room_id == "xiakedao:midao1"

      assert Enum.any?(texts(conn2), &String.contains?(&1, "已经处身在秘密通道中"))
    end

    test "参数不是 bed → :not_handled（LPC `return 0`，放行命令解析）" do
      conn = conn_in("xiakedao:xiaowu", %{"move" => "do_move"})

      assert :not_handled = dispatch(conn, "move desk")
      assert :not_handled = dispatch(conn, "move")
    end
  end

  describe "dispatch/3 对 handler 返回 :not_handled 的透传" do
    test "handler 返回 :not_handled → 分发器也返回 :not_handled" do
      lookup = fn _room_id, _handler -> {:ok, {AlwaysNotHandled, :run}} end
      conn = conn_in("z:r", %{"move" => "do_move"})

      assert :not_handled = RoomActionDispatcher.dispatch(conn, "move bed", lookup)
    end

    test "handler 返回 conn → 仍然 {:handled, conn}" do
      lookup = fn _room_id, _handler -> {:ok, {EchoHandler, :run}} end
      conn = conn_in("z:r", %{"move" => "do_move"})

      assert {:handled, ^conn} = RoomActionDispatcher.dispatch(conn, "move bed", lookup)
    end
  end
end

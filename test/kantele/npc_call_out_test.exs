defmodule Kantele.NpcCallOutTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.CallOutEvent
  alias Kantele.Character.NonPlayerEvents
  alias Kantele.World.NpcActions.CallOut

  defmodule Target do
    def bump(conn, n), do: Map.update(conn, :n, n, &(&1 + n))
  end

  describe "CallOut.schedule/5" do
    test "按 delay 投递 npc/call-out 事件给 NPC 进程" do
      parent = self()

      pid =
        spawn(fn ->
          receive do
            msg -> send(parent, msg)
          end
        end)

      npc = %{id: "npc-1", pid: pid}

      assert :ok = CallOut.schedule(npc, Target, :bump, 0, [3])

      assert_receive %Kalevala.Event{
                       topic: "npc/call-out",
                       data: %{module: Target, function: :bump, args: [3]}
                     },
                     1500
    end

    test "无进程 pid 时返回 {:error, :no_process}" do
      assert {:error, :no_process} = CallOut.schedule(%{id: "npc-1"}, Target, :bump, 6, [])
    end

    test "topic/0 与注册主题一致" do
      assert CallOut.topic() == "npc/call-out"
    end
  end

  describe "CallOutEvent.run/2" do
    test "回调 apply(module, function, [conn | args])" do
      conn = %{n: 1}

      event = %Kalevala.Event{
        topic: "npc/call-out",
        data: %{module: Target, function: :bump, args: [3]}
      }

      assert %{n: 4} = CallOutEvent.run(conn, event)
    end

    test "目标函数/元数不存在时原样返回 conn" do
      conn = %{n: 1}

      missing = %Kalevala.Event{
        topic: "npc/call-out",
        data: %{module: Target, function: :nope, args: []}
      }

      assert ^conn = CallOutEvent.run(conn, missing)

      wrong_arity = %Kalevala.Event{
        topic: "npc/call-out",
        data: %{module: Target, function: :bump, args: []}
      }

      assert ^conn = CallOutEvent.run(conn, wrong_arity)
    end

    test "缺 module/function 时原样返回 conn" do
      conn = %{n: 1}
      event = %Kalevala.Event{topic: "npc/call-out", data: %{}}
      assert ^conn = CallOutEvent.run(conn, event)
    end
  end

  describe "NonPlayerEvents 路由" do
    test "npc/call-out 已注册并路由到 CallOutEvent" do
      conn = %{n: 1}

      event = %Kalevala.Event{
        topic: "npc/call-out",
        data: %{module: Target, function: :bump, args: [5]}
      }

      assert %{n: 6} = NonPlayerEvents.call(conn, event)
    end
  end
end

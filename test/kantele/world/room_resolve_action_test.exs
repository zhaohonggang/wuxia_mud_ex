defmodule Kantele.World.RoomResolveActionTest do
  use ExUnit.Case, async: true

  alias Kantele.World.Room

  defp room_with_actions(actions) do
    %Room{id: "test:room", key: "room", zone_id: "test", actions: actions}
  end

  describe "resolve_action/2" do
    test "在 actions 里找到 verb 返回 handler" do
      room = room_with_actions(%{"move" => "do_move", "climb" => "do_climb"})

      assert {:ok, "do_move"} = Room.resolve_action(room, "move")
      assert {:ok, "do_climb"} = Room.resolve_action(room, "climb")
    end

    test "找不到 verb 返回 :no_such_action" do
      room = room_with_actions(%{"move" => "do_move"})

      assert {:error, :no_such_action} = Room.resolve_action(room, "jump")
    end

    test "大小写敏感（LPC 动词区分大小写）" do
      room = room_with_actions(%{"Move" => "do_move"})

      assert {:ok, "do_move"} = Room.resolve_action(room, "Move")
      assert {:error, :no_such_action} = Room.resolve_action(room, "move")
    end

    test "actions 默认 %{} 时找不到任何 verb" do
      room = %Room{id: "r", key: "r", zone_id: "z"}

      assert {:error, :no_such_action} = Room.resolve_action(room, "move")
    end

    test "非字符串 verb 安全返回错误（不被当成键）" do
      room = room_with_actions(%{"move" => "do_move"})

      assert {:error, :no_such_action} = Room.resolve_action(room, :move)
      assert {:error, :no_such_action} = Room.resolve_action(room, nil)
    end
  end

  describe "resolve_verb/4（兼容旧契约，委托 resolve_action）" do
    test "找到 verb 返回 {:ok, handler}" do
      room = room_with_actions(%{"move" => "do_move"})

      assert {:ok, "do_move"} = Room.resolve_verb(room, "move", %{}, [])
    end

    test "找不到 verb 返回 {:error, :no_such_verb}" do
      room = room_with_actions(%{"move" => "do_move"})

      assert {:error, :no_such_verb} = Room.resolve_verb(room, "jump", %{}, [])
    end
  end
end

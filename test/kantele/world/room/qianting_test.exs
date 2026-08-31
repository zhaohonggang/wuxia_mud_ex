defmodule Kantele.World.Room.QiantingTest do
  use ExUnit.Case, async: true

  alias Kantele.World.Room.Qianting

  defmodule FakePlayer do
    defstruct [:id, :name, :shen]
  end

  defp base_room do
    %{
      state: Qianting.init_room()
    }
  end

  defp player(id, name, shen \\ 0) do
    %FakePlayer{id: id, name: name, shen: shen}
  end

  defp room_with_laopu(opts \\ []) do
    base = base_room()

    Map.put(
      base,
      :state,
      Map.merge(base.state, %{
        laopu_owner_id: Keyword.get(opts, :owner_id, "player:owner"),
        laopu_present: Keyword.get(opts, :present, true),
        laopu_living: Keyword.get(opts, :living, true),
        laopu_owner_permits: Keyword.get(opts, :owner_permits, [])
      })
    )
  end

  test "init_room 初始状态：关门，无 north 出口" do
    room = base_room()
    assert room.state.gate == :close
    refute "north" in room.state.exits
    assert room.state.laopu_present == true
    assert room.state.laopu_living == true
  end

  test "do_push：推门开门，增加 north 出口" do
    player = player("player:owner", "Owner")

    {:ok, room, msgs} = Qianting.do_push(room_with_laopu(), player, nil)

    assert room.state.gate == :open
    assert "north" in room.state.exits
    assert length(msgs) > 0

    # 检查有 vision 消息
    assert Enum.any?(msgs, &(&1.type == :vision))
    # 检查有 broadcast 到 zoudao
    assert Enum.any?(msgs, &(&1.type == :broadcast && &1.target == :zoudao))
    # 检查有 sync_room 到 zoudao
    assert Enum.any?(msgs, &(&1.type == :sync_room && &1.target == "/d/room/panlong/zoudao"))
    # 检查有 cancel_timer + set_timer
    assert Enum.any?(msgs, &(&1.type == :cancel_timer && &1.name == :qianting_auto_close))
    assert Enum.any?(msgs, &(&1.type == :set_timer && &1.name == :qianting_auto_close))
  end

  test "do_push：门已开时报错" do
    room = %{state: %{room_with_laopu().state | gate: :open}}
    {:error, msg} = Qianting.do_push(room, player("p1", "P"), nil)
    assert String.contains?(msg, "大门开着呢")
  end

  test "do_close：关门，移除 north 出口" do
    room = %{
      state: %{room_with_laopu().state | gate: :open, exits: ["south", "east", "west", "north"]}
    }

    {:ok, room, msgs} = Qianting.do_close(room, player("player:owner", "Owner"), nil)

    assert room.state.gate == :close
    refute "north" in room.state.exits
  end

  test "do_close：门已关时报错" do
    room = room_with_laopu()
    {:error, msg} = Qianting.do_close(room, player("p1", "P"), nil)
    assert String.contains?(msg, "大门关着呢")
  end

  test "auto_close_timer：门开时自动关门" do
    room = %{
      state: %{room_with_laopu().state | gate: :open, exits: ["south", "east", "west", "north"]}
    }

    {:ok, room, msgs} = Qianting.auto_close_timer(room, nil)

    assert room.state.gate == :close
    refute "north" in room.state.exits
  end

  test "auto_close_timer：门已关时 noop" do
    room = room_with_laopu()
    {:noop, room} = Qianting.auto_close_timer(room, nil)
    assert room.state.gate == :close
  end

  test "check_valid_leave：往 north 方向，owner 允许" do
    room = base_room()
    player = player("player:owner", "Owner")
    room = room_with_laopu(owner_id: "player:owner")

    {:allow, msg} = Qianting.check_valid_leave(room, player, "north", room)
    assert msg == "请进"
  end

  test "check_valid_leave：往 north 方向，有 permit 允许" do
    room = base_room()
    player = player("player:friend", "Friend")
    room = room_with_laopu(owner_permits: ["player:friend"])

    {:allow, msg} = Qianting.check_valid_leave(room, player, "north", room)
    assert msg == "朋友请进"
  end

  test "check_valid_leave：往 north 方向，无权限拒绝" do
    room = base_room()
    player = player("player:stranger", "Stranger")
    room = room_with_laopu()

    {:deny, msg} = Qianting.check_valid_leave(room, player, "north", room)
    assert msg == "非请莫入"
  end

  test "check_valid_leave：非 north 方向直接放行" do
    room = base_room()
    player = player("player:stranger", "Stranger")
    room = room_with_laopu()

    {:passthrough} = Qianting.check_valid_leave(room, player, "south", room)
  end

  test "check_valid_leave：老仆不在世直接放行" do
    room = base_room()
    player = player("player:stranger", "Stranger")
    room = room_with_laopu(living: false)

    {:passthrough} = Qianting.check_valid_leave(room, player, "north", room)
  end

  test "generate_long：动态描述包含大门状态和老仆" do
    room = base_room()
    long = Qianting.generate_long("Base long.\n", room, true)
    assert String.contains?(long, "大门紧闭")
    assert String.contains?(long, "老仆人扫扫")

    room_open = %{state: %{room_with_laopu().state | gate: :open}}
    long = Qianting.generate_long("Base long.\n", room_open, true)
    assert String.contains?(long, "大门敞开")
  end

  test "respect_title：声望对应称谓" do
    assert Qianting.respect_title(player("p", "P", 15000)) == "大传"
    assert Qianting.respect_title(player("p", "P", 6000)) == "传士"
    assert Qianting.respect_title(player("p", "P", 1000)) == "良善"
    assert Qianting.respect_title(player("p", "P", 100)) == "少传"
    assert Qianting.respect_title(player("p", "P", -1000)) == "恶徒"
    assert Qianting.respect_title(player("p", "P", -10000)) == "魔头"
  end

  test "push_msgs：主人推门消息格式" do
    room = base_room()
    player = player("player:owner", "ZhangSan")
    room = room_with_laopu(owner_id: "player:owner")

    {:ok, _room, msgs} = Qianting.do_push(room, player, room)
    vision_msg = Enum.find(msgs, &(&1.type == :vision))
    assert vision_msg != nil
    assert String.contains?(vision_msg.text, "主人推门")
  end

  test "auto_close_timer：门关时 noop" do
    room = base_room()
    {:noop, _} = Qianting.auto_close_timer(room, room)
    assert room.state.gate == :close
  end
end

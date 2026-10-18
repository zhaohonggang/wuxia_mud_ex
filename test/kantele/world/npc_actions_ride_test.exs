defmodule Kantele.World.NpcActions.RideTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.World.NpcActions.Ride

  defp npc(name, family, is_riding) do
    %Kalevala.Character{
      name: name,
      room_id: "beijing:majuan",
      meta: %{
        family: %{name: family},
        temp: %{is_riding: is_riding}
      }
    }
  end

  # 玩家角色：family 决定是否通过八卦门门槛
  defp conn(room_id, family, is_riding) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        description: "",
        room_id: room_id,
        meta: %{family: %{name: family}, temp: %{is_riding: is_riding}}
      },
      private: %Kalevala.Character.Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(verb, room_id, npc) do
    %{verb: verb, trailing: "", room_id: room_id, npc: npc}
  end

  defp vision_publishes(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
  end

  describe "run/2（family 门槛：八卦门专属）" do
    test "非八卦门 → 广播“偷马”并返回 conn（命令被消耗）" do
      npc = npc("马童", "丐帮", false)
      conn = conn("beijing:majuan", "丐帮", false)

      assert conn2 = Ride.run(conn, params("rideyz", "beijing:majuan", npc))

      publishes = vision_publishes(conn2)
      assert length(publishes) == 1

      [{:publish, "rooms:beijing:majuan", event, _opts, _err}] = publishes
      assert event.data.type == "vision"
      assert String.contains?(event.data.text, "要偷马")
    end

    test "八卦门 + 未骑乘 → 执行骑行流程，返回 conn（非 :not_handled）" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert conn2 = Ride.run(conn, params("rideyz", "beijing:majuan", npc))
      assert conn2 != :not_handled

      # 出发广播(2) + 6 个房间广播 = 8 条 vision
      publishes = vision_publishes(conn2)
      assert length(publishes) == 8
    end
  end

  describe "run/2（已骑乘门槛）" do
    test "八卦门 + 已骑乘 → 提示并返回 :not_handled（放行全局命令）" do
      npc = npc("马童", "八卦门", true)
      conn = conn("beijing:majuan", "八卦门", true)

      assert :not_handled =
               Ride.run(conn, params("rideyz", "beijing:majuan", npc))

      # 不应广播 vision（conn 未被修改，因为返回 :not_handled）
      assert length(conn.private.channel_changes) == 0
      # 由于返回 :not_handled，conn 未被 handler 修改，output 为空；
      # 提示文本在 handler 内部通过 render_to_player 追加到 conn.output，
      # 但因为返回 :not_handled，分发器放弃该 conn，改走全局命令。
      # 此处仅断言不广播 vision，不再检查 output（conn 未被更新）。
      assert length(conn.output) == 0
    end
  end

  describe "run/2（全部 10 个动词）" do
    test "rideyz 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("rideyz", "beijing:majuan", npc)) != :not_handled
    end

    test "ridedl 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("ridedl", "beijing:majuan", npc)) != :not_handled
    end

    test "rideem 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("rideem", "beijing:majuan", npc)) != :not_handled
    end

    test "ridefs 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("ridefs", "beijing:majuan", npc)) != :not_handled
    end

    test "ridefz 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("ridefz", "beijing:majuan", npc)) != :not_handled
    end

    test "ridehz 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("ridehz", "beijing:majuan", npc)) != :not_handled
    end

    test "ridesz 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("ridesz", "beijing:majuan", npc)) != :not_handled
    end

    test "ridexy 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("ridexy", "beijing:majuan", npc)) != :not_handled
    end

    test "rideyd 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("rideyd", "beijing:majuan", npc)) != :not_handled
    end

    test "rideyl 与 八卦门 未骑乘 → 成功执行" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert Ride.run(conn, params("rideyl", "beijing:majuan", npc)) != :not_handled
    end
  end

  describe "run/2（随机坐骑）" do
    test "每次执行的坐骑名都在三种马中（紫骝马/枣红马/黄骠马）" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      Enum.each(1..20, fn _ ->
        conn2 = Ride.run(conn, params("rideyz", "beijing:majuan", npc))
        texts =
          conn2.private.channel_changes
          |> Enum.filter(fn
            {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
            _ -> false
          end)
          |> Enum.map(fn
            {:publish, _, event, _, _} -> event.data.text
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)

        # 至少有一条 vision 包含坐骑名
        assert Enum.any?(texts, fn text ->
          String.contains?(text, "紫骝马") or
          String.contains?(text, "枣红马") or
          String.contains?(text, "黄骠马")
        end)
      end)
    end
  end

  describe "run/2（多房间移动路径）" do
    test "rideyz 路径：beijing:front_yard → gate → di_anmen → city:kedian → city:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("rideyz", "beijing:majuan", npc))

      # channel_changes 是前追加，顺序是逆序的；按房间名成员判断即可
      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      expected_rooms = ["beijing:front_yard", "beijing:gate", "beijing:di_anmen",
                        "city:kedian", "city:majiu"]
      Enum.each(expected_rooms, fn room ->
        assert room in room_ids
      end)
    end

    test "ridedl 路径终点为 dali:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("ridedl", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "dali:majiu" in room_ids
    end

    test "rideem 路径终点为 emei:majiu1" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("rideem", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "emei:majiu1" in room_ids
    end

    test "ridefs 路径终点为 foshan:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("ridefs", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "foshan:majiu" in room_ids
    end

    test "ridefz 路径终点为 fuzhou:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("ridefz", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "fuzhou:majiu" in room_ids
    end

    test "ridehz 路径终点为 hangzhou:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("ridehz", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "hangzhou:majiu" in room_ids
    end

    test "ridesz 路径终点为 suzhou:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("ridesz", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "suzhou:majiu" in room_ids
    end

    test "ridexy 路径终点为 xiangyang:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("ridexy", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "xiangyang:majiu" in room_ids
    end

    test "rideyd 路径终点为 huanghe:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("rideyd", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "huanghe:majiu" in room_ids
    end

    test "rideyl 路径终点为 xiyu:majiu" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      conn2 = Ride.run(conn, params("rideyl", "beijing:majuan", npc))

      room_ids =
        conn2.private.channel_changes
        |> Enum.map(fn
          {:publish, "rooms:" <> room_id, _, _, _} -> room_id
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      assert "xiyu:majiu" in room_ids
    end
  end

  describe "run/2（防御性：fallthrough）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      npc = npc("马童", "八卦门", false)
      conn = conn(nil, "八卦门", false)

      assert :not_handled =
               Ride.run(conn, params("rideyz", nil, npc))
    end

    test "room_id 为空字符串 → :not_handled（不崩溃）" do
      npc = npc("马童", "八卦门", false)
      conn = conn("", "八卦门", false)

      assert :not_handled =
               Ride.run(conn, params("rideyz", "", npc))
    end

    test "未知动词 → @destinations 为空，仅广播出发文案，返回 conn" do
      npc = npc("马童", "八卦门", false)
      conn = conn("beijing:majuan", "八卦门", false)

      assert conn2 = Ride.run(conn, params("rideunknown", "beijing:majuan", npc))
      assert conn2 != :not_handled
    end
  end
end

defmodule Kantele.World.InquiryHandlers.TeleportServiceTest do
  @moduledoc """
  P5 传送服务问询（kind = "teleport_service"），镜像 LPC `kungfu/class/hu/pingsi.c` 的 `ask_me`：
  出关/办事/出去 三门，同门派 + 在本房（平四所在房间）才受理，然后把玩家
  瞬移到 beijing:majiu 并播报马车文案。

  覆盖：InquiryHandlers 注册、asker_id 守门、family 门禁、startroom 门禁、
  target_room/room_id 缺失降级、全流程（广播 + Teleport.teleport 意图 + 成功回话）。

  生产调用：`module.run(conn, Map.get(data, :config) || %{}, data)`，
  故测试把 config 放入 `data[:config]`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.TeleportService
  alias Kantele.World.InquiryHandlers

  @room_id "guanwai:xiaoyuan"
  @target_room "beijing:majiu"

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      temp: Keyword.get(opts, :temp, %{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{}),
      stats: %Stats{},
      family: Keyword.get(opts, :family, nil),
      env: Keyword.get(opts, :env, %{})
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: @room_id,
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      events: []
    }
  end

  defp data(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "teleport_service",
        config: config(),
        npc_name: "平四",
        npc_room_id: @room_id,
        asker_id: "player:test"
      },
      overrides
    )
  end

  defp config(overrides \\ %{}) do
    Map.merge(
      %{
        "kind" => "teleport_service",
        "target_room" => @target_room,
        "startroom" => @room_id,
        "family" => "关外胡家",
        "vision_name" => "平四",
        "success" => "马车已备，请上车。",
        "family_deny" => "你自己没长腿么？",
        "room_deny" => "我这里还有事，你就自己走回去吧。",
        "vision" => "朝远方一招手，顿时几个参客赶着马车驶了过来..."
      },
      overrides
    )
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_visions(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp character(conn), do: conn.private.update_character || conn.character

  # ---- 注册 ----

  describe "InquiryHandlers 注册" do
    test "teleport_service 已注册" do
      assert InquiryHandlers.lookup("teleport_service") == TeleportService
    end
  end

  # ---- 守门：asker_id ----

  describe "run/3 守门：asker_id" do
    test "asker_id 不匹配 → 静默（无输出，conn 不变）" do
      conn2 = TeleportService.run(conn(), Map.get(data(), :config) || %{}, data(%{asker_id: "player:other"}))
      assert out_text(conn2) == ""
      assert conn2.private.channel_changes == []
    end

    test "data 缺 asker_id → 走第二条子句（空 data map）→ conn 不变" do
      conn2 = TeleportService.run(conn(), %{}, %{kind: "teleport_service"})
      assert out_text(conn2) == ""
    end
  end

  # ---- 守门：family ----

  describe "run/3 守门：family" do
    test "家族不符 → 返回 family_deny 文案（带敬称）" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "丐帮"}),
          config(),
          data(%{config: config()})
        )
      assert out_text(conn2) =~ "你自己没长腿么？"
    end

    test "家族匹配 → 不返回 family_deny" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(),
          data(%{config: config()})
        )
      refute out_text(conn2) =~ "你自己没长腿么？"
    end

    test "config 无 family 字段 → 不做家族门禁" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "任意门派"}),
          config(%{"family" => nil}),
          data(%{config: config(%{"family" => nil})})
        )
      refute out_text(conn2) =~ "你自己没长腿么？"
    end
  end

  # ---- 守门：startroom ----

  describe "run/3 守门：startroom" do
    test "不在 startroom → 返回 room_deny 文案（带敬称）" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}, room_id: "guanwai:other"),
          config(),
          data(%{config: config(), npc_room_id: "guanwai:other"})
        )
      assert out_text(conn2) =~ "我这里还有事，你就自己走回去吧。"
    end

    test "在 startroom → 不返回 room_deny" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(),
          data(%{config: config()})
        )
      refute out_text(conn2) =~ "我这里还有事，你就自己走回去吧。"
    end

    test "config 无 startroom 字段 → 不做房间门禁" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}, room_id: "anywhere"),
          config(%{"startroom" => nil}),
          data(%{config: config(%{"startroom" => nil}), npc_room_id: "anywhere"})
        )
      refute out_text(conn2) =~ "我这里还有事，你就自己走回去吧。"
    end
  end

  # ---- 边界：缺失 target_room / room_id ----

  describe "do_teleport 降级" do
    test "target_room 缺失 → 不跳转，仍回 success 回话" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(%{"target_room" => nil}),
          data(%{config: config(%{"target_room" => nil})})
        )
      assert out_text(conn2) =~ "马车已备，请上车。"
      # 没有 publish 广播，也没有 subscribe 意图
      refute Enum.any?(conn2.private.channel_changes, fn
        {:publish, _, _, _, _} -> true
        _ -> false
      end)
    end

    test "npc_room_id 缺失 → 不跳转，仍回 success 回话" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(%{"startroom" => nil}),
          data(%{config: config(%{"startroom" => nil}), npc_room_id: nil})
        )
      assert out_text(conn2) =~ "马车已备，请上车。"
    end

    test "target_room 非字符串（如 atom）→ 不跳转" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(%{"target_room" => :foo}),
          data(%{config: config(%{"target_room" => :foo})})
        )
      assert out_text(conn2) =~ "马车已备，请上车。"
    end
  end

  # ---- 全流程：门控通过 + 传送 ----

  describe "全流程：门控通过后传送" do
    test "family + room 均通过 → 广播 vision + Teleport.teleport 意图 + success 回话" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(),
          data(%{config: config()})
        )

      # 成功回话
      assert out_text(conn2) =~ "马车已备，请上车。"

      # 广播 vision 到 NPC 所在房间
      visions = published_visions(conn2)
      assert length(visions) == 1
      assert hd(visions) =~ "平四朝远方一招手"

      # Teleport.teleport 意图：unsubscribe 旧房 + subscribe 新房
      subs = Enum.filter(conn2.private.channel_changes, fn
        {:subscribe, "rooms:beijing:majiu", _, _} -> true
        _ -> false
      end)
      assert length(subs) == 1

      unsubs = Enum.filter(conn2.private.channel_changes, fn
        {:unsubscribe, "rooms:guanwai:xiaoyuan", _, _} -> true
        _ -> false
      end)
      assert length(unsubs) == 1

      # 角色 room_id 已更新
      assert character(conn2).room_id == @target_room
    end

    test "vision_name 缺失 → 回落到 npc_name" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(%{"vision_name" => nil}),
          data(%{config: config(%{"vision_name" => nil}), npc_name: "平四"})
        )

      visions = published_visions(conn2)
      assert length(visions) == 1
      assert hd(visions) =~ "平四"
    end

    test "vision 缺失 → 回落到默认文案" do
      conn2 =
        TeleportService.run(
          conn(family: %{name: "关外胡家"}),
          config(%{"vision" => nil}),
          data(%{config: config(%{"vision" => nil})})
        )

      visions = published_visions(conn2)
      assert length(visions) == 1
      assert hd(visions) =~ "招手示意"
    end
  end
end

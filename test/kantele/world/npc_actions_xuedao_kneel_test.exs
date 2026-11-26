defmodule Kantele.World.NpcActions.XuedaoKneelTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.NpcActions.XuedaoKneel

  defp shanyong do
    %Kalevala.Character{
      id: "npc-xuedao_shanyong",
      name: "善勇",
      room_id: "xuedao:wangyougu",
      meta: %Kantele.Character.NonPlayerMeta{
        aliases: ["xuedao_shanyong", "shan yong", "shan", "yong"]
      },
      pid: self()
    }
  end

  defp other_npc do
    %Kalevala.Character{
      id: "npc-other",
      name: "其他僧人",
      room_id: "xuedao:wangyougu",
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["qita heseng"]},
      pid: self()
    }
  end

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{shen: 42}),
      env: Keyword.get(opts, :env, %{}),
      family: Keyword.get(opts, :family),
      temp: Keyword.get(opts, :temp, %{pending_join_bonze: true})
    }

    %Conn{
      character: %Kalevala.Character{
        id: Keyword.get(opts, :id, "player:test"),
        name: Keyword.get(opts, :name, "张三"),
        room_id: Keyword.get(opts, :room_id, "xuedao:wangyougu"),
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: "xuedao:wangyougu"},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(opts \\ []) do
    %{
      verb: "kneel",
      trailing: "",
      room_id: Keyword.get(opts, :room_id, "xuedao:wangyougu"),
      npc: Keyword.get(opts, :npc, shanyong())
    }
  end

  defp character(conn), do: conn.private.update_character || conn.character

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp vision_contains?(conn, needle),
    do: Enum.any?(vision_texts(conn), &String.contains?(&1, needle))

  describe "registration" do
    test "xuedao:wangyougu 的 kneel 已注册到 XuedaoKneel" do
      assert {:ok, {XuedaoKneel, :run}} =
               NpcActionHandlers.lookup("xuedao:wangyougu", "kneel")
    end
  end

  describe "run/2 守门（LPC return 0）" do
    test "其他房间 → :not_handled" do
      assert :not_handled =
               XuedaoKneel.run(conn(room_id: "city:kedian", npc: shanyong()), params(room_id: "city:kedian", npc: shanyong()))
    end

    test "同房间但触发 NPC 不是善勇 → :not_handled" do
      assert :not_handled =
               XuedaoKneel.run(conn(room_id: "xuedao:wangyougu", npc: other_npc()), params(room_id: "xuedao:wangyougu", npc: other_npc()))
    end

    test "未 ask 剃度（无 pending）→ :not_handled 且不播文案" do
      conn2 =
        XuedaoKneel.run(
          conn(room_id: "xuedao:wangyougu", temp: %{}, npc: shanyong()),
          params(room_id: "xuedao:wangyougu", npc: shanyong())
        )

      assert :not_handled = conn2
    end
  end

  describe "剃度仪式（LPC shanyong.c do_kneel）" do
    setup do
      {:ok, conn: XuedaoKneel.run(conn(npc: shanyong()), params(npc: shanyong()))}
    end

    test "pending/join_bonze 已删除", %{conn: conn2} do
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
      refute PlayerMeta.get_temp(character(conn2).meta, "pending/join_bonze")
    end

    test "class 置为 bonze（无门派时也建立裸 family map）", %{conn: conn2} do
      assert character(conn2).meta.family == %{class: "bonze"}
    end

    test "不改名（姓名保持不变）", %{conn: conn2} do
      assert character(conn2).name == "张三"
    end

    test "播报剃发 vision + NPC 说 + ke 微笑", %{conn: conn2} do
      assert vision_contains?(conn2, "双手合十，恭恭敬敬地跪了下来。")
      assert vision_contains?(conn2, "善勇伸出手掌，在{npc}头顶轻轻地摩挲了几下，将{npc}的头发尽数剃去。")
      assert vision_contains?(conn2, "善勇说道：既然你皈依我佛，我便收你为徒。")
      assert vision_contains?(conn2, "善勇点了点头。")
    end
  end

  test "已有门派时保留门派字段，只覆写 class" do
    family = %{name: "丐帮", master_id: "npc-hong", master_name: "洪七公"}
    conn2 =
      XuedaoKneel.run(conn(family: family, npc: shanyong()), params(npc: shanyong()))

    assert character(conn2).meta.family == %{
             name: "丐帮",
             master_id: "npc-hong",
             master_name: "洪七公",
             class: "bonze"
           }
  end

  test "LPC 字符串 pending key 同样生效" do
    conn2 =
      XuedaoKneel.run(
        conn(temp: %{"pending/join_bonze" => 1}, npc: shanyong()),
        params(npc: shanyong())
      )

    assert character(conn2).meta.family == %{class: "bonze"}
    refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
  end
end

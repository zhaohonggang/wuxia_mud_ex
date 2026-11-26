defmodule Kantele.World.NpcActions.XueshanKneelTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.NpcActions.XueshanKneel

  defp gelunbu do
    %Kalevala.Character{
      id: "npc-xueshan_gelunbu",
      name: "葛伦布",
      room_id: "xueshan:shanmen",
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["xueshan_gelunbu", "ge lunbu", "ge", "lunbu"]},
      pid: self()
    }
  end

  defp jiamu do
    %Kalevala.Character{
      id: "npc-xueshan_jiamu",
      name: "嘉木活佛",
      room_id: "xueshan:cedian1",
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["xueshan_jiamu", "jiamu huofo", "huofo", "jiamu"]},
      pid: self()
    }
  end

  defp lazhang do
    %Kalevala.Character{
      id: "npc-xueshan_lazhang",
      name: "拉章活佛",
      room_id: "xueshan:dadian",
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["xueshan_lazhang", "lazhang huofo", "lazhang", "huofo"]},
      pid: self()
    }
  end

  defp samu do
    %Kalevala.Character{
      id: "npc-xueshan_samu",
      name: "萨木活佛",
      room_id: "xueshan:cedian2",
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["xueshan_samu", "samu huofo", "huofo", "samu"]},
      pid: self()
    }
  end

  defp other_npc do
    %Kalevala.Character{
      id: "npc-other",
      name: "知客僧",
      room_id: "xueshan:shanmen",
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["zhikeseng"]},
      pid: self()
    }
  end

  defp conn(room_id, opts \\ []) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{shen: 42}),
      combat: Keyword.get(opts, :combat, %{PKS: 2, MKS: 3}),
      env: Keyword.get(opts, :env, %{}),
      family: Keyword.get(opts, :family),
      temp: Keyword.get(opts, :temp, %{pending_join_bonze: true})
    }

    %Conn{
      character: %Kalevala.Character{
        id: Keyword.get(opts, :id),
        name: Keyword.get(opts, :name, "张三"),
        room_id: room_id,
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, opts \\ []) do
    %{
      verb: "kneel",
      trailing: "",
      room_id: room_id,
      npc: Keyword.get(opts, :npc)
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
    test "xueshan:shanmen 的 kneel 已注册到 XueshanKneel" do
      assert {:ok, {XueshanKneel, :run}} = NpcActionHandlers.lookup("xueshan:shanmen", "kneel")
    end

    test "xueshan:cedian1 的 kneel 已注册到 XueshanKneel" do
      assert {:ok, {XueshanKneel, :run}} = NpcActionHandlers.lookup("xueshan:cedian1", "kneel")
    end

    test "xueshan:dadian 的 kneel 已注册到 XueshanKneel" do
      assert {:ok, {XueshanKneel, :run}} = NpcActionHandlers.lookup("xueshan:dadian", "kneel")
    end

    test "xueshan:cedian2 的 kneel 已注册到 XueshanKneel" do
      assert {:ok, {XueshanKneel, :run}} = NpcActionHandlers.lookup("xueshan:cedian2", "kneel")
    end

    test "shaolin:guangchang1 仍注册到 ShaolinKneel（两处不互相覆盖）" do
      assert {:ok, {Kantele.World.NpcActions.ShaolinKneel, :run}} =
               NpcActionHandlers.lookup("shaolin:guangchang1", "kneel")
    end
  end

  describe "run/2 守门（LPC return 0）" do
    test "其他房间 → :not_handled" do
      assert :not_handled = XueshanKneel.run(conn("city:kedian", npc: gelunbu()), params("city:kedian", npc: gelunbu()))
    end

    test "同房间但触发 NPC 不是对应大轮寺 NPC → :not_handled" do
      assert :not_handled = XueshanKneel.run(conn("xueshan:shanmen"), params("xueshan:shanmen", npc: other_npc()))
    end

    test "未 ask 剃度（无 pending）→ :not_handled 且不播文案" do
      conn2 = XueshanKneel.run(conn("xueshan:shanmen", temp: %{}, npc: gelunbu()), params("xueshan:shanmen", npc: gelunbu()))
      assert :not_handled = conn2
    end
  end

  describe "剃度仪式（LPC tobebonze.h do_kneel）" do
    setup do
      {:ok, conn: XueshanKneel.run(conn("xueshan:shanmen", npc: gelunbu()), params("xueshan:shanmen", npc: gelunbu()))}
    end

    test "pending/join_bonze 已删除", %{conn: conn2} do
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
      refute PlayerMeta.get_temp(character(conn2).meta, "pending/join_bonze")
    end

    test "class 置为 bonze（无门派时也建立裸 family map）", %{conn: conn2} do
      assert character(conn2).meta.family == %{class: "bonze"}
    end

    test "title 置为 大轮寺喇嘛", %{conn: conn2} do
      assert character(conn2).meta.title == "大轮寺喇嘛"
    end

    test "不改名（姓名保持不变）", %{conn: conn2} do
      assert character(conn2).name == "张三"
    end

    test "不清 shen，不置 shen_record/K_record", %{conn: conn2} do
      meta = character(conn2).meta
      assert meta.stats.shen == 42
      assert meta.env[:shen_record] == nil
      assert meta.env[:K_record] == nil
    end

    test "播报剃发 vision + NPC 说 + nod 微笑", %{conn: conn2} do
      assert vision_contains?(conn2, "双手合十，恭恭敬敬地跪了下来。")
      assert vision_contains?(conn2, "葛伦布伸出手掌，在{npc}头顶轻轻地摩挲了几下，将{npc}的头发尽数剃去。")
      assert vision_contains?(conn2, "葛伦布说道：既然出了家，就得一心向佛，再不能还俗。")
      assert vision_contains?(conn2, "葛伦布愉快地微笑着。")
    end
  end

  test "已有门派时保留门派字段，只覆写 class" do
    family = %{name: "大理段氏", master_id: "npc-duan", master_name: "段正淳"}
    conn2 = XueshanKneel.run(conn("xueshan:cedian1", family: family, npc: jiamu()), params("xueshan:cedian1", npc: jiamu()))

    assert character(conn2).meta.family == %{
             name: "大理段氏",
             master_id: "npc-duan",
             master_name: "段正淳",
             class: "bonze"
           }
    assert character(conn2).meta.title == "大轮寺喇嘛"
  end

  test "LPC 字符串 pending key 同样生效" do
    conn2 = XueshanKneel.run(conn("xueshan:dadian", temp: %{"pending/join_bonze" => 1}, npc: lazhang()), params("xueshan:dadian", npc: lazhang()))
    assert character(conn2).meta.title == "大轮寺喇嘛"
    assert character(conn2).meta.family == %{class: "bonze"}
  end

  test "四个 NPC 各在各自房间，title 均为 大轮寺喇嘛" do
    assert xueshan_kneel_ok("xueshan:shanmen", gelunbu())
    assert xueshan_kneel_ok("xueshan:cedian1", jiamu())
    assert xueshan_kneel_ok("xueshan:dadian", lazhang())
    assert xueshan_kneel_ok("xueshan:cedian2", samu())
  end

  defp xueshan_kneel_ok(room_id, npc) do
    conn2 = XueshanKneel.run(conn(room_id, npc: npc), params(room_id, npc: npc))
    character(conn2).meta.title == "大轮寺喇嘛" and character(conn2).meta.family == %{class: "bonze"}
  end
end

defmodule Kantele.World.NpcActions.ShaolinKneelTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.NpcActions.ShaolinKneel

  @room_id "shaolin:guangchang1"
  @npc_name "清法比丘"

  defp qingfa do
    %Kalevala.Character{
      id: "npc-shaolin_qing_fa",
      name: @npc_name,
      room_id: @room_id,
      meta: %Kantele.Character.NonPlayerMeta{
        aliases: ["shaolin_qing_fa", "qingfa biqiu", "qingfa", "biqiu"]
      },
      pid: self()
    }
  end

  defp other_npc do
    %Kalevala.Character{
      id: "npc-other",
      name: "知客僧",
      room_id: @room_id,
      meta: %Kantele.Character.NonPlayerMeta{aliases: ["zhikeseng"]},
      pid: self()
    }
  end

  defp conn(opts \\ []) do
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
        room_id: @room_id,
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(opts \\ []) do
    %{
      verb: "kneel",
      trailing: "",
      room_id: Keyword.get(opts, :room_id, @room_id),
      npc: Keyword.get(opts, :npc, qingfa())
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
    test "shaolin:guangchang1 的 kneel 已注册到 ShaolinKneel" do
      assert {:ok, {ShaolinKneel, :run}} = NpcActionHandlers.lookup(@room_id, "kneel")
    end

    test "乾隆房间仍注册到 Kneel（两处不互相覆盖）" do
      assert {:ok, {Kantele.World.NpcActions.Kneel, :run}} =
               NpcActionHandlers.lookup("hangzhou:liuhe9", "kneel")
    end
  end

  describe "run/2 守门（LPC return 0）" do
    test "其他房间 → :not_handled" do
      assert :not_handled = ShaolinKneel.run(conn(), params(room_id: "city:kedian"))
    end

    test "同房间但触发 NPC 不是清法 → :not_handled" do
      assert :not_handled = ShaolinKneel.run(conn(), params(npc: other_npc()))
    end

    test "未 ask 剃度（无 pending）→ :not_handled 且不播文案" do
      conn2 = ShaolinKneel.run(conn(temp: %{}), params())
      assert :not_handled = conn2
    end
  end

  describe "剃度仪式（LPC qing-fa.c do_kneel）" do
    setup do
      {:ok, conn: ShaolinKneel.run(conn(), params())}
    end

    test "法名 = 四字姓之一 + 原名首字", %{conn: conn2} do
      new_name = character(conn2).name
      assert String.ends_with?(new_name, "张")
      assert String.starts_with?(new_name, "虚") or String.starts_with?(new_name, "空") or
               String.starts_with?(new_name, "明") or String.starts_with?(new_name, "净")

      assert String.length(new_name) == 2
    end

    test "pending/join_bonze 已删除", %{conn: conn2} do
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
      refute PlayerMeta.get_temp(character(conn2).meta, "pending/join_bonze")
    end

    test "class 置为 bonze（无门派时也建立裸 family map）", %{conn: conn2} do
      assert character(conn2).meta.family == %{class: "bonze"}
    end

    test "K_record = PKS + MKS，shen_record = 旧 shen，shen 清零", %{conn: conn2} do
      meta = character(conn2).meta
      assert meta.env[:K_record] == 5
      assert meta.env[:shen_record] == 42
      assert meta.stats.shen == 0
    end

    test "播报剃发 vision + NPC 说法名 + smile", %{conn: conn2} do
      assert vision_contains?(conn2, "双手合十，恭恭敬敬地跪了下来。")
      assert vision_contains?(conn2, "#{@npc_name}伸出手掌，在{npc}头顶轻轻地摩挲了几下，将{npc}的头发尽数剃去。")
      assert vision_contains?(conn2, "#{@npc_name}说道：从今以后你的法名叫做")
      assert vision_contains?(conn2, "#{@npc_name}愉快地微笑着。")
    end
  end

  test "已有门派时保留门派字段，只覆写 class" do
    family = %{name: "少林派", master_id: "npc-qingwu", master_name: "清无比丘"}
    conn2 = ShaolinKneel.run(conn(family: family), params())

    assert character(conn2).meta.family == %{
             name: "少林派",
             master_id: "npc-qingwu",
             master_name: "清无比丘",
             class: "bonze"
           }
  end

  test "LPC 字符串 pending key 同样生效" do
    conn2 = ShaolinKneel.run(conn(temp: %{"pending/join_bonze" => 1}), params())
    assert character(conn2).meta.env[:K_record] == 5
  end
end

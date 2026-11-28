defmodule Kantele.World.NpcActions.EmeiKneelTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.NpcActions.EmeiKneel

  @npc_rooms [
    {"emei:fushouan", "emei_zhen", "静真师太"},
    {"emei:hcaguangchang", "emei_xu", "静虚师太"},
    {"emei:hcazhengdian", "emei_xin", "静心师太"},
    {"emei:lingwenge", "emei_zhao", "静照师太"},
    {"emei:qfadadian", "emei_hui", "静慧师太"},
    {"emei:qingyinge", "emei_xian", "静闲师太"},
    {"emei:wanxingan", "emei_jia", "静迦师太"},
    {"emei:wnadian", "emei_kong", "静空师太"},
    {"emei:woyunan", "emei_xuan", "静玄师太"}
  ]

  defp npc(alias_key, name) do
    %Kalevala.Character{
      id: "npc-#{alias_key}",
      name: name,
      meta: %Kantele.Character.NonPlayerMeta{aliases: [alias_key, String.replace(name, "师太", "")]},
      pid: self()
    }
  end

  defp conn(room_id, opts) do
    meta = %PlayerMeta{
      stats: Keyword.get(opts, :stats, %Stats{shen: 42}),
      combat: Keyword.get(opts, :combat, %{temp: %{PKS: 2, MKS: 3}}),
      env: Keyword.get(opts, :env, %{gender: "女性", purename: "赵敏"}),
      family: Keyword.get(opts, :family, %{name: "峨嵋派"}),
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

  defp params(room_id, npc), do: %{verb: "kneel", trailing: "", room_id: room_id, npc: npc}

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
    test "九名师太房间的 kneel 均注册到 EmeiKneel" do
      Enum.each(@npc_rooms, fn {room_id, _key, _name} ->
        assert {:ok, {EmeiKneel, :run}} = NpcActionHandlers.lookup(room_id, "kneel")
      end)
    end

    test "少林/大轮寺/血刀 kneel 注册未被覆盖" do
      assert {:ok, {Kantele.World.NpcActions.ShaolinKneel, :run}} =
               NpcActionHandlers.lookup("shaolin:guangchang1", "kneel")

      assert {:ok, {Kantele.World.NpcActions.XueshanKneel, :run}} =
               NpcActionHandlers.lookup("xueshan:shanmen", "kneel")

      assert {:ok, {Kantele.World.NpcActions.XuedaoKneel, :run}} =
               NpcActionHandlers.lookup("xuedao:wangyougu", "kneel")
    end
  end

  describe "run/2 守门（LPC return 0）" do
    test "其他房间 → :not_handled" do
      hui = npc("emei_hui", "静慧师太")

      assert :not_handled =
               EmeiKneel.run(conn("city:kedian", npc: hui), params("city:kedian", hui))
    end

    test "同房间但触发 NPC 不是对应师太 → :not_handled" do
      other = npc("emei_wenyin", "静音师太")

      assert :not_handled =
               EmeiKneel.run(conn("emei:qfadadian", npc: other), params("emei:qfadadian", other))
    end

    test "未 ask 剃度（无 pending）→ :not_handled 且不播文案" do
      hui = npc("emei_hui", "静慧师太")

      conn2 =
        EmeiKneel.run(conn("emei:qfadadian", temp: %{}, npc: hui), params("emei:qfadadian", hui))

      assert :not_handled = conn2
    end
  end

  describe "剃度仪式（LPC tobebonze.h do_kneel）" do
    setup do
      hui = npc("emei_hui", "静慧师太")

      {:ok,
       conn:
         EmeiKneel.run(
           conn("emei:qfadadian", npc: hui),
           params("emei:qfadadian", hui)
         )}
    end

    test "pending/join_bonze 已删除（atom/string 双键）", %{conn: conn2} do
      refute PlayerMeta.get_temp(character(conn2).meta, :pending_join_bonze)
      refute PlayerMeta.get_temp(character(conn2).meta, "pending/join_bonze")
    end

    test "class 置为 bonze，并保留原门派字段", %{conn: conn2} do
      assert character(conn2).meta.family == %{name: "峨嵋派", class: "bonze"}
    end

    test "法名取灵/文/心/妙之一 + purename 首字", %{conn: conn2} do
      name = character(conn2).name

      assert String.starts_with?(name, "灵") or String.starts_with?(name, "文") or
               String.starts_with?(name, "心") or String.starts_with?(name, "妙")

      assert String.graphemes(name) == [String.first(name), "赵"]
    end

    test "无 purename 时以姓名首字起法名" do
      hui = npc("emei_hui", "静慧师太")

      conn2 =
        EmeiKneel.run(
          conn("emei:qfadadian", env: %{gender: "女性"}, npc: hui),
          params("emei:qfadadian", hui)
        )

      assert String.graphemes(character(conn2).name) == [String.first(character(conn2).name), "张"]
    end

    test "marks/old_name 保存 purename", %{conn: conn2} do
      marks = character(conn2).meta.marks
      assert marks[:old_name] == "赵敏"
      assert marks["old_name"] == "赵敏"
    end

    test "K_record=PKS+MKS，shen_record 保存剃度前 shen，shen 清零", %{conn: conn2} do
      meta = character(conn2).meta
      assert meta.env[:K_record] == 5
      assert meta.env[:shen_record] == 42
      assert meta.stats.shen == 0
    end

    test "播报全文 vision、NPC 说法名、nod 微笑", %{conn: conn2} do
      assert vision_contains?(conn2, "{npc}你双手合十，恭恭敬敬地跪了下来。")
      assert vision_contains?(conn2, "静慧师太看着{npc}说道：好吧，以后你就在本庵修行吧。")
      assert vision_contains?(conn2, "静慧师太伸出手掌，在{npc}头顶轻轻地摩挲了几下，随即便将{npc}的头发尽数剃去。")
      assert vision_contains?(conn2, "静慧师太说道：从今以后你的法名叫做#{character(conn2).name}。")
      assert vision_contains?(conn2, "静慧师太愉快地微笑着。")
    end
  end

  test "LPC 字符串 pending key 同样生效" do
    hui = npc("emei_hui", "静慧师太")

    conn2 =
      EmeiKneel.run(
        conn("emei:qfadadian", temp: %{"pending/join_bonze" => 1}, npc: hui),
        params("emei:qfadadian", hui)
      )

    assert character(conn2).meta.family == %{name: "峨嵋派", class: "bonze"}
  end

  test "九名师太各在各自房间，剃度均生效" do
    Enum.each(@npc_rooms, fn {room_id, key, name} ->
      master = npc(key, name)
      conn2 = EmeiKneel.run(conn(room_id, npc: master), params(room_id, master))

      assert character(conn2).meta.family.class == "bonze"

      assert String.starts_with?(character(conn2).name, "灵") or
               String.starts_with?(character(conn2).name, "文") or
               String.starts_with?(character(conn2).name, "心") or
               String.starts_with?(character(conn2).name, "妙")
    end)
  end
end

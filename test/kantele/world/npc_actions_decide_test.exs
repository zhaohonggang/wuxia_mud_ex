defmodule Kantele.World.NpcActions.DecideTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Decide

  defp npc(name), do: %Kalevala.Character{name: name}

  defp conn(room_id, meta_opts \\ %{}, attrs \\ %{}) do
    meta = struct(%PlayerMeta{}, meta_opts)

    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: room_id,
        attributes: attrs,
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, npc, trailing \\ "") do
    %{verb: "decide", trailing: trailing, room_id: room_id, npc: npc}
  end

  defp run(conn, params) do
    case Decide.run(conn, params) do
      :not_handled -> :not_handled
      conn2 -> apply_updates(conn2)
    end
  end

  defp apply_updates(%Conn{} = conn) do
    case conn.private.update_character do
      nil -> conn
      character -> %{conn | character: character}
    end
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  describe "run/2 分派" do
    test "未注册房间 → :not_handled" do
      npc = npc("陆小凤")
      assert :not_handled = Decide.run(conn("unknown:room"), params("unknown:room", npc))
    end

    test "room_id 为 nil → :not_handled（不崩溃）" do
      npc = npc("陆小凤")
      assert :not_handled = Decide.run(conn(nil), params(nil, npc))
    end

    test "未移植的 decide 房间（海公公/水笙）→ :not_handled 放行" do
      npc = npc("海公公")

      assert :not_handled =
               Decide.run(conn("beijing:dongchang"), params("beijing:dongchang", npc))

      assert :not_handled = Decide.run(conn("register:entry"), params("register:entry", npc))
    end
  end

  describe "陆小凤（guiyun:taihu）" do
    test "无 guiyun/decide 标记 → 反问“你要决定干嘛”" do
      npc = npc("陆小凤")
      conn2 = run(conn("guiyun:taihu"), params("guiyun:taihu", npc))

      assert conn2 != :not_handled
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "你要决定干嘛"))
    end

    test "命中 guiyun/decide 标记 → 注销标记并播报引荐文案" do
      npc = npc("陆小凤")
      conn = conn("guiyun:taihu", %{temp: %{"guiyun/decide" => 1}})

      conn2 = run(conn, params("guiyun:taihu", npc))
      texts = vision_texts(conn2)

      assert conn2.character.meta.temp["guiyun/decide"] == nil
      assert Enum.any?(texts, &String.contains?(&1, "有劳少庄主费心了"))
      assert Enum.any?(texts, &String.contains?(&1, "一封书信"))
      assert Enum.any?(texts, &String.contains?(&1, "盘恒数日"))
    end
  end

  describe "黄真（xiangyang:qianzhuang）" do
    test "无 want_join/want_tuoli → 没理你" do
      npc = npc("黄真")
      conn2 = run(conn("xiangyang:qianzhuang"), params("xiangyang:qianzhuang", npc))

      assert String.contains?(out_text(conn2), "没理你")
    end

    test "want_join → 设 is_vendor 并注销标记" do
      npc = npc("黄真")
      conn = conn("xiangyang:qianzhuang", %{temp: %{"want_join" => 1}})

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))

      assert conn2.character.meta.env["is_vendor"] == 1
      assert conn2.character.meta.temp["want_join"] == nil
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "钱乃万能之物"))
    end

    test "want_tuoli → 清 is_vendor、设 bad_vendor 并注销标记" do
      npc = npc("黄真")

      conn =
        conn("xiangyang:qianzhuang", %{env: %{"is_vendor" => 1}, temp: %{"want_tuoli" => 1}})

      conn2 = run(conn, params("xiangyang:qianzhuang", npc))

      refute Map.has_key?(conn2.character.meta.env, "is_vendor")
      assert conn2.character.meta.env["bad_vendor"] == 1
      assert conn2.character.meta.temp["want_tuoli"] == nil
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "人各有志"))
    end
  end
end

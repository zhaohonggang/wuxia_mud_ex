defmodule Kantele.World.NpcActions.ServeTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.World.NpcActions.Serve

  defp npc(name), do: %Kalevala.Character{name: name}

  # 构造带内嵌物品定义的实例（instance_item 命中 `item` 字段，不经世界数据）
  defp inst(id, name, aliases) do
    %Instance{
      id: Instance.generate_id(),
      item_id: id,
      item: %Item{id: id, name: name, meta: %{aliases: aliases}},
      created_at: ~U[2026-10-18 00:00:00Z]
    }
  end

  defp conn(room_id, inventory \\ []) do
    %Conn{
      character: %Kalevala.Character{name: "玩家", room_id: room_id, inventory: inventory},
      private: %Conn.Private{
        room: %Kantele.World.Room{id: room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, npc) do
    %{verb: "serve", trailing: "", room_id: room_id, npc: npc}
  end

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Serve.run(conn(nil), params(nil, npc("厨师")))
    end

    test "room_id 为空字符串 → :not_handled（不崩溃）" do
      assert :not_handled = Serve.run(conn(""), params("", npc("厨师")))
    end
  end

  describe "run/2（守卫：身上已有）" do
    test "身上同时有饭和茶 → 拒绝「你身上不是还有么」" do
      npc = npc("厨师")
      inventory = [inst("wuguan:rice", "饭", ["rice", "fan"]), inst("wuguan:tea", "茶", ["tea", "cha"])]
      conn2 = Serve.run(conn("wuguan:guofu_fanting", inventory), params("wuguan:guofu_fanting", npc))

      assert conn2 != :not_handled
      assert String.contains?(out_text(conn2), "你身上不是还有么")
      # 拒绝时不广播 vision
      assert vision_texts(conn2) == []
    end

    test "身上只有饭 → 守卫不触发（走发饭茶路径）" do
      npc = npc("厨师")
      inventory = [inst("wuguan:rice", "饭", ["rice", "fan"])]
      conn2 = Serve.run(conn("wuguan:guofu_fanting", inventory), params("wuguan:guofu_fanting", npc))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "你慢用"))
    end
  end

  describe "run/2（成功路径）" do
    test "wuguan 饭厅：广播「递到手中」并返回 conn" do
      npc = npc("厨师")
      conn2 = Serve.run(conn("wuguan:guofu_fanting"), params("wuguan:guofu_fanting", npc))

      assert conn2 != :not_handled
      texts = vision_texts(conn2)
      assert Enum.any?(texts, &String.contains?(&1, "厨师将热气腾腾的饭菜递到"))
      assert Enum.any?(texts, &String.contains?(&1, "你慢用"))
      assert [{:publish, "rooms:wuguan:guofu_fanting", _event, _opts, _err}] =
               conn2.private.channel_changes
    end

    test "meizhuang 厨房：同一 handler 复用（参数化仅房间不同）" do
      npc = npc("厨师")
      conn2 = Serve.run(conn("meizhuang:chufang"), params("meizhuang:chufang", npc))

      assert conn2 != :not_handled
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "你慢用"))

      assert [{:publish, "rooms:meizhuang:chufang", _event, _opts, _err}] =
               conn2.private.channel_changes
    end
  end
end

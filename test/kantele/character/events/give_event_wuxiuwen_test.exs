defmodule Kantele.Character.GiveEvent.WuxiuwenTest do
  @moduledoc """
  P5 打工闭环：武修文收还工具的两端。

  - `WuxiuwenAccept.handle/5`（武修文进程侧）：判定给来的是不是五种打工工具
    （wuguan:items.chutou/piao/juzi/chaidao/saozhou），收下进背包；否则拒收。
  - `GiveEvent.wuxiuwen_returned/2`（玩家进程侧）：校验「完成标记 + job_name」后
    落 `mark/还了`（LPC `set_temp("mark/还了", 1)`），否则回拒绝文案。

  与 LPC wuxiuwen.c `accept_object` 对应：先干完活（Wuguan.Work 写 mark/X完了）→
  再还工具 → mark/还了 落定，task ok 成功分支方可直达。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kantele.World.WuxiuwenAccept

  @valid_tools %{
    "chutou" => "wuguan:items.chutou",
    "piao" => "wuguan:items.piao",
    "juzi" => "wuguan:items.juzi",
    "chaidao" => "wuguan:items.chaidao",
    "saozhou" => "wuguan:items.saozhou"
  }
  @wrong "wuguan:items.rice"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    # 兜底：若环境未加载 wuguan.ucl 工具/米饭，则临时塞入；只清理自己加的。
    ids = Map.values(@valid_tools) ++ [@wrong]

    added =
      Enum.filter(ids, fn id ->
        case Items.get(id) do
          {:ok, _} -> false
          _ -> Items.put(id, %Item{id: id, name: id, verbs: [], callback_module: Kantele.World.Item, meta: %{}})
        end
      end)

    on_exit(fn ->
      for id <- added, do: Items.delete(id)
    end)

    :ok
  end

  # ---- WuxiuwenAccept.handle（武修文进程侧收工具） ----

  defp npc_conn do
    meta = %PlayerMeta{stats: %Stats{}}

    %Conn{
      character: %Kalevala.Character{
        id: "wuguan:wuxiuwen",
        name: "武修文",
        room_id: "wuguan:wuxiuwen",
        inventory: [],
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp instance(item_id) do
    %Instance{
      id: "inst_#{:erlang.unique_integer([:monotonic])}",
      item_id: item_id,
      created_at: DateTime.utc_now()
    }
  end

  defp npc_inventory_ids(conn), do: Enum.map(conn.private.update_character.inventory, & &1.item_id)

  describe "WuxiuwenAccept.handle（武修文收工具）" do
    test "给对工具（chutou）→ 收下进武修文背包" do
      conn0 = npc_conn()
      data = %{reply_to: self(), from_id: "player:test"}
      inst = instance("wuguan:items.chutou")

      conn1 = WuxiuwenAccept.handle(conn0, conn0.character, inst, data, "玩家")

      assert "wuguan:items.chutou" in npc_inventory_ids(conn1)
    end

    test "五种工具都收下（按活计遍历）" do
      for tool_id <- Map.values(@valid_tools) do
        conn0 = npc_conn()
        data = %{reply_to: self(), from_id: "player:test"}
        inst = instance(tool_id)

        conn1 = WuxiuwenAccept.handle(conn0, conn0.character, inst, data, "玩家")
        assert tool_id in npc_inventory_ids(conn1), "工具 #{tool_id} 被拒收"
      end
    end

    test "给错东西（rice）→ 拒收，背包不变" do
      conn0 = npc_conn()
      data = %{reply_to: self(), from_id: "player:test"}
      inst = instance("wuguan:items.rice")

      conn1 = WuxiuwenAccept.handle(conn0, conn0.character, inst, data, "玩家")

      assert npc_inventory_ids(conn1) == []
    end
  end

  # ---- GiveEvent.wuxiuwen_returned（玩家侧落 mark/还了） ----

  defp player_conn(opts) do
    meta = %PlayerMeta{
      temp: Keyword.get(opts, :temp, %{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{}),
      stats: %Stats{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: "wuguan:guofu_mafang",
        inventory: [],
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp character(conn), do: conn.private.update_character || conn.character
  defp temp_get(conn, key), do: PlayerMeta.get_temp(character(conn).meta, key)

  describe "GiveEvent.wuxiuwen_returned（落 mark/还了）" do
    test "已完成 + 有活计 → 写 mark/还了 + 回话" do
      conn0 = player_conn(temp: %{"job_name" => "打扫马房", "mark/扫完了" => 1})

      conn1 =
        GiveEvent.wuxiuwen_returned(conn0, %{
          data: %{ok: true, message: "干得不错，你现在去耶律师兄那儿领取酬劳吧。\n"}
        })

      assert temp_get(conn1, "mark/还了") == 1
      assert out_text(conn1) =~ "干得不错"
    end

    test "未完成（无完成 mark）→ 拒：「你还没完成工作」" do
      conn0 = player_conn(temp: %{"job_name" => "打扫马房"})

      conn1 = GiveEvent.wuxiuwen_returned(conn0, %{data: %{ok: true, message: "x"}})

      assert temp_get(conn1, "mark/还了") == nil
      assert out_text(conn1) =~ "你还没完成工作，怎么就回来还工具了，偷懒吗？"
    end

    test "完成但没活计（job_name 空）→ 拒：「你没有发给你过东西」" do
      conn0 = player_conn(temp: %{"mark/扫完了" => 1})

      conn1 = GiveEvent.wuxiuwen_returned(conn0, %{data: %{ok: true, message: "x"}})

      assert temp_get(conn1, "mark/还了") == nil
      assert out_text(conn1) =~ "我没有发给你过东西，你是不是还错了？"
    end

    test "ok:false → 直接回拒收文案（不置 mark/还了）" do
      conn0 = player_conn(temp: %{"job_name" => "打扫马房", "mark/扫完了" => 1})

      conn1 =
        GiveEvent.wuxiuwen_returned(conn0, %{
          data: %{ok: false, message: "你还错东西了吧，我从没有发过这样工具。\n"}
        })

      assert temp_get(conn1, "mark/还了") == nil
      assert out_text(conn1) =~ "你还错东西了吧"
    end
  end
end

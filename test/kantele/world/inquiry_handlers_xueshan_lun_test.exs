defmodule Kantele.World.InquiryHandlers.XueshanLunTest do
  @moduledoc """
  大轮寺 #797：金轮法王 ask_lun（日月金轮）定向测试。
  LPC 依据：`kungfu/class/xueshan/fawang.c:774-834`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Items, Loader}
  alias Kantele.World.InquiryHandlers.XueshanLun

  setup_all do
    %{world: Loader.load()}
  end

  setup do
    Items.put("clone_lib:jinlun", %ItemDef{
      id: "clone_lib:jinlun",
      name: "日月金轮",
      verbs: ["get", "drop", "wield", "unwield"],
      meta: %{aliases: ["riyue jinlun"]}
    })

    :ok
  end

  defp conn(overrides \\ []) do
    family = Keyword.get(overrides, :family, %{name: "大轮寺", master_id: "npc:fawang"})

    meta = %PlayerMeta{
      stats: Keyword.get(overrides, :stats, %Stats{shen: -60000}),
      vitals: %Vitals{qi: 100, max_qi: 100},
      env: %{},
      family: family,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xueshan:dadian",
        inventory: Keyword.get(overrides, :inventory, []),
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp cfg(overrides \\ %{}) do
    %{"kind" => "xueshan_lun", "item" => "clone_lib:jinlun"}
    |> Map.merge(overrides)
  end

  defp data(overrides) do
    %{
      kind: "xueshan_lun",
      config: cfg(),
      npc_id: "npc:fawang",
      npc_name: "金轮法王",
      npc_room_id: "xueshan:dadian",
      asker_id: "player:test",
      asker_name: "测试玩家",
      owner: %{kind: :npc, name: "金轮法王", family: nil}
    }
    |> Map.merge(Map.new(overrides))
  end

  defp run(c, overrides \\ []), do: XueshanLun.run(c, cfg(), data(overrides))

  defp out_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} when is_binary(data) -> data
      %Conn.EventText{text: %Conn.Text{data: iodata}} -> IO.iodata_to_binary(iodata)
      _ -> ""
    end)
    |> Enum.join()
  end

  defp vision_text(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Event{data: %{text: text}}, _opts, _error_fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  describe "UCL 数据落地" do
    test "日月金轮键指向 xueshan_lun 且携带 item", %{world: world} do
      fawang = Enum.find(world.characters, &(&1.name == "金轮法王"))
      inquiry = fawang.meta.inquiries["日月金轮"]

      assert inquiry["kind"] == "xueshan_lun"
      assert inquiry["item"] == "clone_lib:jinlun"
    end

    test "xueshan_lun kind 已注册" do
      assert InquiryHandlers.lookup("xueshan_lun") ==
               Kantele.World.InquiryHandlers.XueshanLun
    end
  end

  describe "is_good 前门（shen > 500）" do
    test "大轮寺弟子 is_good → 同门大怒 message_vision，无文字" do
      conn2 = run(conn(stats: %Stats{shen: 600}))

      assert out_text(conn2) == ""
      assert vision_text(conn2) =~ "金轮法王大怒，对测试玩家道"
      assert vision_text(conn2) =~ "反而学起假仁假义来了，给我滚吧！"
    end

    test "非大轮寺 is_good → 外人大怒 message_vision" do
      conn2 = run(conn(stats: %Stats{shen: 600}, family: %{name: "少林派"}))

      assert out_text(conn2) == ""
      assert vision_text(conn2) =~ "居然敢贪图我的随身利器，活得不耐烦了？"
    end
  end

  describe "顺序门控" do
    test "非大轮寺 → 日月金轮是我的随身兵器…" do
      conn2 = run(conn(family: %{name: "少林派"}))
      assert out_text(conn2) =~ "日月金轮是我的随身兵器，你打听它干什么？"
    end

    test "大轮寺非嫡传 → 只有我的弟子才配…" do
      conn2 = run(conn(family: %{name: "大轮寺"}))
      assert out_text(conn2) =~ "只有我的弟子才配使用金轮，你还是自己下去练练吧。"
    end

    test "嫡传但 shen > -50000 → 哼！你既然如此侠义…" do
      conn2 = run(conn(stats: %Stats{shen: -49999}))
      assert out_text(conn2) =~ "哼！你既然如此侠义，还是别用金轮的好。"
    end

    test "shen 恰为 -50000 不拦（LPC 是 > 不是 >=）" do
      conn2 = run(conn(stats: %Stats{shen: -50000}))
      refute out_text(conn2) =~ "哼！你既然如此侠义"
      assert out_text(conn2) == ""
    end
  end

  describe "持有者遍历（owner）" do
    test "owner=:asker（自己拿着）→ 怎么？日月金轮不就是你拿着在用吗？" do
      conn2 = run(conn(), owner: %{kind: :asker, name: "测试玩家", family: nil})
      assert out_text(conn2) =~ "怎么？日月金轮不就是你拿着在用吗？"
    end

    test "owner=:object（不在法王手中）→ 你来晚了一步…" do
      conn2 = run(conn(), owner: %{kind: :object, name: "日月金轮", family: nil})
      assert out_text(conn2) =~ "你来晚了一步，日月金轮现在不在我手中。"
    end

    test "owner=:character 同门 → 金轮现在暂时是你同门师兄{name}在用…" do
      conn2 = run(conn(), owner: %{kind: :character, name: "达尔巴", family: "大轮寺"})

      assert out_text(conn2) =~ "金轮现在暂时是你同门师兄达尔巴在用，你要用就去找他吧。"
    end

    test "owner=:character 外人 → 我的日月金轮现在落在{name}手中，去把他做了…" do
      conn2 = run(conn(), owner: %{kind: :character, name: "郭靖", family: "丐帮"})

      assert out_text(conn2) =~ "我的日月金轮现在落在郭靖手中，你去把他做了，把金轮抢回来！"
    end

    test "owner=nil（法王手中）→ give + 微笑 vision" do
      conn2 = run(conn(), owner: nil)
      assert vision_text(conn2) =~ "金轮法王微微笑道：念在你平时刻苦努力"
      assert Enum.any?(character(conn2).inventory, &(&1.item_id == "clone_lib:jinlun"))
    end
  end

  test "非提问者的回执 → conn 不变" do
    c = conn()
    assert c == XueshanLun.run(c, cfg(), data(asker_id: "player:other"))
  end

  test "非 map data → 返回 conn 不变" do
    c = conn()
    assert c == XueshanLun.run(c, cfg(), "not a map")
  end

  defp character(conn), do: conn.private.update_character || conn.character
end

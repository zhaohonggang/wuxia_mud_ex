defmodule Kantele.World.InquiryHandlers.XuedaoTreasureTest do
  @moduledoc """
  血刀派 #793：血刀老祖 ask_dao/ask_book（血刀/血刀经）定向测试。
  LPC 依据：`kungfu/class/xuedao/laozu.c:697-823`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Items, Loader}
  alias Kantele.World.InquiryHandlers.XuedaoTreasure

  setup_all do
    %{world: Loader.load()}
  end

  setup do
    Items.put("clone_lib:xuedao", %ItemDef{
      id: "clone_lib:xuedao",
      name: "血刀",
      verbs: ["get", "drop", "wield", "unwield"]
    })

    Items.put("clone_lib:xuedao_jing", %ItemDef{
      id: "clone_lib:xuedao_jing",
      name: "血刀经",
      verbs: ["get", "drop"]
    })

    :ok
  end

  defp conn(overrides \\ []) do
    family = Keyword.get(overrides, :family, %{name: "血刀门", master_id: "npc:laozu"})

    stats = Keyword.get(overrides, :stats, %Stats{shen: -60000, combat_exp: 400000})

    # 允许通过 :skills 单独覆盖技能表（如 xuedao-dafa 等级门控测试）
    stats = if skills = Keyword.get(overrides, :skills) do
      %{stats | skills: skills}
    else
      stats
    end

    meta = %PlayerMeta{
      stats: stats,
      vitals: %Vitals{qi: 100, max_qi: 100},
      env: %{},
      family: family,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "xuedao:laozu",
        inventory: Keyword.get(overrides, :inventory, []),
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp dao_cfg(overrides \\ %{}) do
    %{"kind" => "xuedao_dao", "item" => "clone_lib:xuedao"}
    |> Map.merge(overrides)
  end

  defp book_cfg(overrides \\ %{}) do
    %{"kind" => "xuedao_book", "item" => "clone_lib:xuedao_jing"}
    |> Map.merge(overrides)
  end

  defp dao_data(overrides) do
    %{
      kind: "xuedao_dao",
      config: dao_cfg(),
      npc_id: "npc:laozu",
      npc_name: "血刀老祖",
      npc_room_id: "xuedao:laozu",
      asker_id: "player:test",
      asker_name: "测试玩家",
      owner: %{kind: :npc, name: "血刀老祖", family: nil}
    }
    |> Map.merge(Map.new(overrides))
  end

  defp book_data(overrides) do
    %{
      kind: "xuedao_book",
      config: book_cfg(),
      npc_id: "npc:laozu",
      npc_name: "血刀老祖",
      npc_room_id: "xuedao:laozu",
      asker_id: "player:test",
      asker_name: "测试玩家",
      owner: %{kind: :npc, name: "血刀老祖", family: nil}
    }
    |> Map.merge(Map.new(overrides))
  end

  defp run_dao(c, overrides \\ []), do: XuedaoTreasure.run(c, dao_cfg(), dao_data(overrides))
  defp run_book(c, overrides \\ []), do: XuedaoTreasure.run(c, book_cfg(), book_data(overrides))

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
    test "血刀键指向 xuedao_dao 且携带 item", %{world: world} do
      laozu = Enum.find(world.characters, &(&1.name == "血刀老祖"))
      inquiry = laozu.meta.inquiries["血刀"]

      assert inquiry["kind"] == "xuedao_dao"
      assert inquiry["item"] == "clone_lib:xuedao"
    end

    test "血刀经键指向 xuedao_book 且携带 item", %{world: world} do
      laozu = Enum.find(world.characters, &(&1.name == "血刀老祖"))
      inquiry = laozu.meta.inquiries["血刀经"]

      assert inquiry["kind"] == "xuedao_book"
      assert inquiry["item"] == "clone_lib:xuedao_jing"
    end

    test "xuedao_dao kind 已注册" do
      assert InquiryHandlers.lookup("xuedao_dao") == Kantele.World.InquiryHandlers.XuedaoTreasure
    end

    test "xuedao_book kind 已注册" do
      assert InquiryHandlers.lookup("xuedao_book") == Kantele.World.InquiryHandlers.XuedaoTreasure
    end
  end

  describe "ask_dao：is_good 前门（shen > 500，message_vision 房间广播）" do
    test "血刀门弟子 is_good → 同门大怒，无私有文字，不发血刀" do
      conn2 = run_dao(conn(stats: %Stats{shen: 600, combat_exp: 400000}))

      assert out_text(conn2) == ""
      assert vision_text(conn2) =~ "血刀老祖大怒，对测试玩家道"
      assert vision_text(conn2) =~ "反而学起假仁假义来了，居然还有脸问我要本门之宝"
      refute out_text(conn2) =~ "拿去"
      refute Enum.any?(character(conn2).inventory, &(&1.item_id == "clone_lib:xuedao"))
    end

    test "非血刀门 is_good → 外人大怒，无私有文字" do
      conn2 = run_dao(conn(stats: %Stats{shen: 600}, family: %{name: "少林派"}))

      assert out_text(conn2) == ""
      assert vision_text(conn2) =~ "血刀老祖大怒，对测试玩家喝道"
      assert vision_text(conn2) =~ "居然敢贪图本门至宝"
    end
  end

  describe "ask_dao：顺序门控" do
    test "非血刀门 → 血刀是我血刀门至宝，你打听它干什么？" do
      conn2 = run_dao(conn(family: %{name: "少林派"}))
      assert out_text(conn2) =~ "血刀是我血刀门至宝，你打听它干什么？"
    end

    test "血刀门非嫡传 → 只有我的弟子才能用血刀，你还是自己下去练练吧。" do
      conn2 = run_dao(conn(family: %{name: "血刀门"}))
      assert out_text(conn2) =~ "只有我的弟子才能用血刀，你还是自己下去练练吧。"
    end

    test "嫡传但 shen > -50000 → 你邪气不重，使用不了血刀。" do
      conn2 = run_dao(conn(stats: %Stats{shen: -49999, combat_exp: 400000}))
      assert out_text(conn2) =~ "你邪气不重，使用不了血刀。"
    end

    test "shen 恰为 -50000 不拦（LPC 是 > 不是 >=）" do
      conn2 = run_dao(conn(stats: %Stats{shen: -50000, combat_exp: 400000}))
      refute out_text(conn2) =~ "你邪气不重"
      assert out_text(conn2) == ""
    end
  end

  describe "ask_book：顺序门控" do
    test "非血刀门 → 哪里来的野种，竟敢打我血刀门的主意？" do
      conn2 = run_book(conn(family: %{name: "少林派"}))
      assert out_text(conn2) =~ "哪里来的野种，竟敢打我血刀门的主意？"
    end

    test "血刀门非嫡传 → 你又不是老夫的弟子，跟老夫啰嗦些什么？" do
      conn2 = run_book(conn(family: %{name: "血刀门"}))
      assert out_text(conn2) =~ "你又不是老夫的弟子，跟老夫啰嗦些什么？"
    end

    test "嫡传但 shen > -50000 → 你倒是学起假仁假义来了…" do
      conn2 = run_book(conn(stats: %Stats{shen: -49999, combat_exp: 400000}))
      assert out_text(conn2) =~ "你倒是学起假仁假义来了，让老夫如何能相信你？"
    end

    test "combat_exp < 300000 → 你现在经验太浅，这本血刀经你还看不懂。" do
      conn2 = run_book(conn(stats: %Stats{shen: -60000, combat_exp: 200000}))
      assert out_text(conn2) =~ "你现在经验太浅，这本血刀经你还看不懂。"
    end

    test "combat_exp 恰为 300000 不拦" do
      conn2 = run_book(conn(stats: %Stats{shen: -60000, combat_exp: 300000}))
      refute out_text(conn2) =~ "经验太浅"
      assert out_text(conn2) == ""
    end

    test "xuedao-dafa > 179 → 火候已经很深了，血刀经对你起不了什么作用。" do
      conn2 =
        run_book(
          conn(
            stats: %Stats{shen: -60000, combat_exp: 400000},
            skills: %{"xuedao-dafa" => 180}
          )
        )

      assert out_text(conn2) =~ "你的血刀大法火候已经很深了，血刀经对你起不了什么作用。"
    end

    test "xuedao-dafa 恰为 179 不拦（LPC 是 > 不是 >=）" do
      conn2 =
        run_book(
          conn(
            stats: %Stats{shen: -60000, combat_exp: 400000},
            skills: %{"xuedao-dafa" => 179}
          )
        )

      refute out_text(conn2) =~ "火候已经很深"
      assert out_text(conn2) == ""
    end
  end

  describe "持有者遍历（owner）" do
    test "ask_dao owner=:asker → 他奶奶的，本门的血刀现在不是你拿着在用吗？" do
      conn2 = run_dao(conn(), owner: %{kind: :asker, name: "测试玩家", family: nil})
      assert out_text(conn2) =~ "他奶奶的，本门的血刀现在不是你拿着在用吗？"
    end

    test "ask_book owner=:asker → 我血刀门的宝经不就是你拿着在看吗？" do
      conn2 = run_book(conn(), owner: %{kind: :asker, name: "测试玩家", family: nil})
      assert out_text(conn2) =~ "我血刀门的宝经不就是你拿着在看吗？"
    end

    test "owner=:object → 你来晚了一步，血刀现在不在我手中。" do
      conn2 = run_dao(conn(), owner: %{kind: :object, name: "血刀", family: nil})
      assert out_text(conn2) =~ "你来晚了一步，血刀现在不在我手中。"
    end

    test "ask_book owner=:object → …嗯…血刀经现在不在我手里。" do
      conn2 = run_book(conn(), owner: %{kind: :object, name: "血刀经", family: nil})
      assert out_text(conn2) =~ "…嗯…血刀经现在不在我手里。"
    end

    test "owner=:character 同门 → 血刀现在暂时是你同门师兄{name}在用，你要用就去找他吧。" do
      conn2 = run_dao(conn(), owner: %{kind: :character, name: "某师兄", family: "血刀门"})
      assert out_text(conn2) =~ "血刀现在暂时是你同门师兄某师兄在用，你要用就去找他吧。"
    end

    test "owner=:character 同门（血刀经）→ 血刀经现在暂时被你同门的{name}取去看了，你要看就去找他吧。" do
      conn2 = run_book(conn(), owner: %{kind: :character, name: "某师兄", family: "血刀门"})
      assert out_text(conn2) =~ "血刀经现在暂时被你同门的某师兄取去看了，你要看就去找他吧。"
    end

    test "owner=:character 外人 → 本门的血刀现在落在{name}手中，你去把他做了，把血刀抢回来！" do
      conn2 = run_dao(conn(), owner: %{kind: :character, name: "郭靖", family: "丐帮"})
      assert out_text(conn2) =~ "本门的血刀现在落在郭靖手中，你去把他做了，把血刀抢回来！"
    end

    test "owner=:character 外人（血刀经）→ 我血刀门的宝经现在落在了{name}手中，你去把它夺回来吧！" do
      conn2 = run_book(conn(), owner: %{kind: :character, name: "郭靖", family: "丐帮"})
      assert out_text(conn2) =~ "我血刀门的宝经现在落在了郭靖手中，你去把它夺回来吧！"
    end

    test "ask_dao owner=nil（老祖手中）→ give + 哈哈 vision" do
      conn2 = run_dao(conn(), owner: nil)
      assert vision_text(conn2) =~ "血刀老祖哈哈一笑，道：好，乖徒儿，这柄血刀你就拿去"
      assert Enum.any?(character(conn2).inventory, &(&1.item_id == "clone_lib:xuedao"))
    end

    test "ask_book owner=nil（老祖手中）→ give + 点头 vision" do
      conn2 = run_book(conn(), owner: nil)
      assert vision_text(conn2) =~ "血刀老祖点头道：这本血刀经你就拿去看吧，可要仔细阅读。"
      assert Enum.any?(character(conn2).inventory, &(&1.item_id == "clone_lib:xuedao_jing"))
    end
  end

  test "非提问者的回执 → conn 不变（ask_dao）" do
    c = conn()
    assert c == XuedaoTreasure.run(c, dao_cfg(), dao_data(asker_id: "player:other"))
  end

  test "非提问者的回执 → conn 不变（ask_book）" do
    c = conn()
    assert c == XuedaoTreasure.run(c, book_cfg(), book_data(asker_id: "player:other"))
  end

  test "非 map data → 返回 conn 不变" do
    c = conn()
    assert c == XuedaoTreasure.run(c, dao_cfg(), "not a map")
    assert c == XuedaoTreasure.run(c, book_cfg(), "not a map")
  end

  defp character(conn), do: conn.private.update_character || conn.character
end

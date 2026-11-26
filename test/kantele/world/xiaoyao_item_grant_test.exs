defmodule Kantele.World.XiaoyaoItemGrantTest do
  @moduledoc """
  逍遥派 #805 冯阿三铁八卦/布阵箱、#806 苟读论语 定向测试。

  LPC 依据：
    - `fengas.c:59-68,100-154`：family + master_id OR（wuya zi / su xinghe）
      + qimen-wuxing>=80 + random 初值库存 + 两句耗尽文案；
    - `goudu.c:27-29,62-78,78,100-141`：嫡传独占 lbook4（已被取走则专属文案），
      同门非嫡传 book_count>0 时随机 strike_book / hand_book + 独立 message_vision。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.{PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Items, Loader}

  setup_all do
    %{world: Loader.load()}
  end

  setup do
    for {id, name, aliases} <- [
          {"taohua:bagua", "铁八卦", ["tie bagua", "bagua"]},
          {"taohua:xiang", "布阵箱", ["buzhen xiang", "xiang"]},
          {"clone_lib:lbook4", "「论语」", ["lbook4"]},
          {"clone_lib:strike_book", "拳谱", ["strike_book"]},
          {"clone_lib:hand_book", "手法谱", ["hand_book"]}
        ] do
      Items.put(id, %ItemDef{
        id: id,
        name: name,
        verbs: [],
        meta: %{aliases: aliases}
      })
    end

    :ok
  end

  defp conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp player(overrides \\ %{}) do
    %Kalevala.Character{
      id: "player:test",
      name: "测试玩家",
      room_id: "xiaoyao:muwu1",
      inventory: [],
      meta: %PlayerMeta{
        family: %{name: "逍遥派", master_id: "su xinghe"},
        stats: %Stats{skills: %{"qimen_wuxing" => 80}},
        env: %{},
        temp: %{},
        vitals: %Vitals{qi: 100, max_qi: 100, jing: 100, max_jing: 100, neili: 100, max_neili: 100}
      }
    }
    |> Map.merge(overrides)
  end

  defp data(overrides \\ %{}) do
    %{
      kind: "npc_item_grant",
      npc_id: "npc:test",
      npc_name: "冯阿三",
      npc_room_id: "xiaoyao:muwu1",
      npc_pid: nil,
      asker_id: "player:test",
      asker_name: "测试玩家",
      remaining: 1,
      fallback_remaining: 1
    }
    |> Map.merge(overrides)
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: text} -> text
      %Conn.EventText{text: %Conn.Text{data: text}} -> text
      _ -> ""
    end)
    |> Enum.join("")
  end

  defp inventory_ids(conn) do
    character = conn.private.update_character || conn.character
    Enum.map(character.inventory || [], & &1.item_id)
  end

  # message_vision 走 channel publish，不在 conn.output。
  defp vision_text(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _error_fun} -> text
      _ -> ""
    end)
    |> Enum.join("")
  end

  defp non_disciple do
    player(%{meta: %{player().meta | family: %{name: "逍遥派", master_id: "other"}}})
  end

  defp config(overrides \\ %{}) do
    %{
      "kind" => "npc_item_grant",
      "item" => "taohua:bagua",
      "match" => "tie bagua",
      "family" => "逍遥派",
      "allowed_master_ids" => ["wuya zi", "su xinghe"],
      "min_skill_levels" => %{"qimen_wuxing" => 80},
      "count" => "bagua_count",
      "vision_msg" => "{npc}拿出一只铁八卦给{name}。",
      "success" => "这只铁八卦你就先拿去用吧。",
      "family_deny" => "你是谁？哪里来的？我认识你么？",
      "master_deny" => "哈哈，你刚入我逍遥派就问我要东西？",
      "min_skill_deny" => "你又不懂奇门五行，拿去干嘛用？",
      "no_item" => "我这里也没有了，你自己去城里买一个吧。"
    }
    |> Map.merge(overrides)
  end

  describe "UCL 数据落地" do
    defp npc(world, alias_key) do
      Enum.find(world.characters, fn c ->
        Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
      end)
    end

    test "冯阿三两个问询均转 npc_item_grant，物品跨区引用解析正确", %{world: world} do
      fengas = npc(world, "feng asan")

      bagua = fengas.meta.inquiries["铁八卦"]
      xiang = fengas.meta.inquiries["布阵箱"]

      assert bagua["kind"] == "npc_item_grant"
      assert bagua["item"] == "taohua:bagua"
      assert bagua["allowed_master_ids"] == ["wuya zi", "su xinghe"]
      assert bagua["min_skill_levels"] == %{"qimen_wuxing" => 80}

      assert xiang["kind"] == "npc_item_grant"
      assert xiang["item"] == "taohua:xiang"
      assert xiang["no_item"] == "我这里也没有了，你等两天再来吧。"
      refute String.contains?(bagua["success"], "\\n")
    end

    test "冯阿三随机初值库存在 0..1 之间（random(5)>3 / random(4)>2）", %{world: world} do
      state = npc(world, "feng asan").meta.inquiry_state

      assert Map.get(state, "bagua_count") in [0, 1]
      assert Map.get(state, "xiang_count") in [0, 1]
    end

    test "苟读论语：lbook4 + 两本随机回退书 + 双库存", %{world: world} do
      goudu = npc(world, "gou du")
      inquiry = goudu.meta.inquiries["论语"]

      assert inquiry["kind"] == "npc_item_grant"
      assert inquiry["item"] == "clone_lib:lbook4"
      assert inquiry["fallback_items"] == ["clone_lib:strike_book", "clone_lib:hand_book"]
      assert inquiry["fallback_count"] == "book_count"
      assert inquiry["vision_msg"] == "{npc}从怀里掏出一本旧书，交了给{name}。"

      assert inquiry["fallback_vision_msg"] ==
               "{npc}翻箱倒柜找了半天，找出一本旧书，交了给{name}。"

      assert goudu.meta.inquiry_state["lunyu_count"] == 1
      assert goudu.meta.inquiry_state["book_count"] == 1
    end
  end

  describe "#805 铁八卦/布阵箱门控" do
    test "master_id OR：wuya zi 与 su xinghe 均放行" do
      for master <- ["wuya zi", "su xinghe"] do
        character =
          player(%{meta: %{player().meta | family: %{name: "逍遥派", master_id: master}}})

        result = InquiryHandlers.lookup("npc_item_grant").run(conn(character), config(), data())
        assert output_text(result) =~ "这只铁八卦你就先拿去用吧。"
        assert "taohua:bagua" in inventory_ids(result)
      end
    end

    test "非指定师父拒绝，奇门五行不足拒绝" do
      outsider =
        player(%{meta: %{player().meta | family: %{name: "逍遥派", master_id: "other"}}})

      result = InquiryHandlers.lookup("npc_item_grant").run(conn(outsider), config(), data())
      assert output_text(result) =~ "哈哈，你刚入我逍遥派就问我要东西？"

      weak = player()
      weak_meta = %{weak.meta | stats: %Stats{skills: %{"qimen_wuxing" => 79}}}
      result = InquiryHandlers.lookup("npc_item_grant").run(conn(%{weak | meta: weak_meta}), config(), data())
      assert output_text(result) =~ "你又不懂奇门五行，拿去干嘛用？"
    end

    test "库存耗尽回各自文案" do
      result =
        InquiryHandlers.lookup("npc_item_grant").run(
          conn(player()),
          config(),
          data(%{remaining: 0})
        )

      assert output_text(result) =~ "我这里也没有了，你自己去城里买一个吧。"
    end
  end

  describe "#806 论语嫡传与回退分支" do
    defp lunyu_config(overrides \\ %{}) do
      config(%{
        "item" => "clone_lib:lbook4",
        "match" => "lbook4",
        "min_skill_levels" => %{},
        "count" => "lunyu_count",
        "vision_msg" => "{npc}从怀里掏出一本旧书，交了给{name}。",
        "success" => "这本书可千万不要借给别人啊，他们一借就不还的了。",
        "no_item" => "你来晚了，那本《论语》我已经赠送给别入了。",
        "family_deny" => "干嘛你要？",
        "fallback_items" => ["clone_lib:strike_book", "clone_lib:hand_book"],
        "fallback_count" => "book_count",
        "fallback_vision_msg" => "{npc}翻箱倒柜找了半天，找出一本旧书，交了给{name}。",
        "fallback_success" => "这本书可千万不要借给别人啊，他们一借就不还的了。",
        "fallback_no_item" => "我现在手头没有什么书了。"
      })
      |> Map.merge(overrides)
    end

    test "嫡传：发放论语并播从怀里掏书文案" do
      disciple = player(%{meta: %{player().meta | family: %{name: "逍遥派", master_id: "wuya zi"}}})

      result =
        InquiryHandlers.lookup("npc_item_grant").run(
          conn(disciple),
          lunyu_config(),
          data(%{npc_name: "苟读"})
        )

      assert "clone_lib:lbook4" in inventory_ids(result)
      assert vision_text(result) =~ "从怀里掏出一本旧书"
      assert output_text(result) =~ "这本书可千万不要借给别人啊"
    end

    test "论语已被取走：专属文案（非通用 no_item）" do
      disciple = player(%{meta: %{player().meta | family: %{name: "逍遥派", master_id: "wuya zi"}}})

      result =
        InquiryHandlers.lookup("npc_item_grant").run(
          conn(disciple),
          lunyu_config(),
          data(%{npc_name: "苟读", remaining: 0})
        )

      assert output_text(result) =~ "你来晚了，那本《论语》我已经赠送给别入了。"
    end

    test "同门非嫡传：随机回退书 + 翻箱倒柜文案" do
      result =
        InquiryHandlers.lookup("npc_item_grant").run(
          conn(non_disciple()),
          lunyu_config(),
          data(%{npc_name: "苟读"})
        )

      assert Enum.any?(inventory_ids(result), &(&1 in ["clone_lib:strike_book", "clone_lib:hand_book"]))
      assert vision_text(result) =~ "翻箱倒柜找了半天"
    end

    test "回退库存耗尽：我现在手头没有什么书了" do
      result =
        InquiryHandlers.lookup("npc_item_grant").run(
          conn(non_disciple()),
          lunyu_config(),
          data(%{npc_name: "苟读", fallback_remaining: 0})
        )

      assert output_text(result) =~ "我现在手头没有什么书了。"
    end

    test "非逍遥派仍按 family_deny 拒绝" do
      outsider = player(%{meta: %{player().meta | family: %{name: "星宿派", master_id: "ding"}}})

      result =
        InquiryHandlers.lookup("npc_item_grant").run(
          conn(outsider),
          lunyu_config(),
          data(%{npc_name: "苟读"})
        )

      assert output_text(result) =~ "干嘛你要？"
    end
  end
end

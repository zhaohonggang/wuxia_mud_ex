defmodule Kantele.World.InquiryHandlers.GiveItemEmeiTest do
  @moduledoc """
  #854 静风师太「伤药/软剑」give_item 库存门定向测试。

  镜像 LPC `feng.c`：
  - `ask_yao()`：`present("tianxiang gao")` 已持有 → 拒；`gao_count < 1` 库存 → 拒
    （已持有 → 库存顺序）
  - `ask_jian()`：`jian_count < 1` 库存 → 拒；`present("ruanjian")` 已持有 → 拒
    （库存 → 已持有顺序，需 `exhausted_before_already = true`）

  覆盖：
  - 受伤门（require_wounded）：qi >= max_qi → wound_deny
  - 已持有门（plain_already）：无 RANK_D 敬称前缀
  - 库存门（exhausted）：remaining <= 0 → exhausted
  - 伤药顺序：已持有 → 库存（未设 exhausted_before_already）
  - 软剑顺序：库存 → 已持有（exhausted_before_already = true）
  - 门派门：family_deny
  - 发放成功：success 文案 + npc/inquiry_consume 扣库存
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem

  defp medicine_config do
    %{
      "kind" => "give_item",
      "item" => "emei:tianxiang_gao",
      "match" => "tianxiang gao",
      "count" => "gao_count",
      "family" => "峨嵋派",
      "family_deny" => "与本派素无来往，不知此话从何谈起？",
      "require_wounded" => true,
      "wound_deny" => "你未曾受伤，讨这药膏做什么？",
      "plain_already" => true,
      "already" => "你身上不是带着本门秘药？",
      "exhausted" => "你来晚了，本门秘药已尽数给了本派弟子。",
      "success" => "我这里有本门秘药，你拿去疗伤吧。"
    }
  end

  defp sword_config do
    %{
      "kind" => "give_item",
      "item" => "emei:ruanjian",
      "match" => "ruanjian",
      "count" => "jian_count",
      "family" => "峨嵋派",
      "family_deny" => "与本派素无来往，不知此话从何谈起？",
      "plain_already" => true,
      "exhausted_before_already" => true,
      "already" => "你身上不是带着武器吗？怎么还来要！",
      "exhausted" => "我现在没有什么武器好给，你下次在来吧。",
      "success" => "我这里有一把软剑，你拿去用吧。"
    }
  end

  defp conn(opts \\ []) do
    family = Keyword.get(opts, :family, %{name: "峨嵋派"})
    qi = Keyword.get(opts, :qi, 80)
    max_qi = Keyword.get(opts, :max_qi, 100)
    inventory = Keyword.get(opts, :inventory, [])

    meta = %PlayerMeta{
      vitals: %Vitals{qi: qi, max_qi: max_qi},
      stats: %Stats{combat_exp: 2_000_000, shen: 0, skills: %{"sword" => 0}},
      family: family,
      temp: %{}
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "emei:jingjing",
        inventory: inventory,
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "emei_feng",
      npc_name: "静风师太",
      npc_pid: self(),
      npc_room_id: "emei:jingjing",
      remaining: Keyword.get(opts, :remaining, 1)
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> data
      %Conn.EventText{text: %Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  defp channel_texts(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  defp tianxiang_gao_instance do
    %Instance{id: "instance:tianxiang_gao", item_id: "emei:tianxiang_gao"}
  end

  defp ruanjian_instance do
    %Instance{id: "instance:ruanjian", item_id: "emei:ruanjian"}
  end

  describe "伤药：受伤门（require_wounded）" do
    test "qi >= max_qi（未受伤）：返回 wound_deny" do
      conn0 = conn(qi: 100, max_qi: 100)
      result = GiveItem.run(conn0, medicine_config(), data())

      assert output_text(result) =~ "你未曾受伤，讨这药膏做什么？"
    end

    test "qi < max_qi（已受伤）：不过受伤门，继续后续门控" do
      conn0 = conn(qi: 50, max_qi: 100)
      result = GiveItem.run(conn0, medicine_config(), data())

      refute output_text(result) =~ "你未曾受伤"
    end
  end

  describe "伤药：已持有 → 库存顺序（未设 exhausted_before_already）" do
    test "已持有天香膏，库存充足：返回 already，无敬称前缀（plain_already）" do
      conn0 = conn(inventory: [tianxiang_gao_instance()])
      result = GiveItem.run(conn0, medicine_config(), data())

      assert output_text(result) =~ "你身上不是带着本门秘药？"
      refute output_text(result) =~ "大侠"
    end

    test "未持有，库存耗尽（remaining = 0）：返回 exhausted" do
      conn0 = conn()
      result = GiveItem.run(conn0, medicine_config(), data(remaining: 0))

      assert output_text(result) =~ "你来晚了，本门秘药已尽数给了本派弟子。"
    end

    test "已持有且库存耗尽：already 先于 exhausted（伤药顺序）" do
      conn0 = conn(inventory: [tianxiang_gao_instance()])
      result = GiveItem.run(conn0, medicine_config(), data(remaining: 0))

      # 伤药未设 exhausted_before_already → already 先于 exhausted
      assert output_text(result) =~ "你身上不是带着本门秘药？"
      refute output_text(result) =~ "你来晚了，本门秘药已尽数给了本派弟子。"
    end
  end

  describe "软剑：库存 → 已持有顺序（exhausted_before_already = true）" do
    test "库存耗尽（remaining = 0），未持有：返回 exhausted" do
      conn0 = conn()
      result = GiveItem.run(conn0, sword_config(), data(remaining: 0))

      assert output_text(result) =~ "我现在没有什么武器好给，你下次在来吧。"
    end

    test "库存耗尽且已持有软剑：exhausted 先于 already（软剑顺序）" do
      conn0 = conn(inventory: [ruanjian_instance()])
      result = GiveItem.run(conn0, sword_config(), data(remaining: 0))

      # 软剑设置了 exhausted_before_already → exhausted 先于 already
      assert output_text(result) =~ "我现在没有什么武器好给，你下次在来吧。"
      refute output_text(result) =~ "你身上不是带着武器吗？怎么还来要！"
    end

    test "库存充足且已持有软剑：返回 already" do
      conn0 = conn(inventory: [ruanjian_instance()])
      result = GiveItem.run(conn0, sword_config(), data(remaining: 1))

      assert output_text(result) =~ "你身上不是带着武器吗？怎么还来要！"
    end
  end

  describe "门派门（family_deny）" do
    test "非峨嵋派玩家：返回 family_deny" do
      conn0 = conn(family: %{name: "少林派"})
      result = GiveItem.run(conn0, medicine_config(), data())

      assert output_text(result) =~ "与本派素无来往，不知此话从何谈起？"
    end
  end

  describe "发放成功与库存扣减（npc/inquiry_consume）" do
    test "伤药发放成功：输出 success 并向 NPC 发送 inquiry_consume" do
      conn0 = conn(qi: 50, max_qi: 100)
      result = GiveItem.run(conn0, medicine_config(), data(remaining: 1))

      assert output_text(result) =~ "我这里有本门秘药，你拿去疗伤吧。"

      assert_receive %Kalevala.Event{
        topic: "npc/inquiry_consume",
        data: %{count_key: "gao_count"}
      }, 200
    end

    test "软剑发放成功：输出 success 并向 NPC 发送 inquiry_consume" do
      conn0 = conn(qi: 50, max_qi: 100)
      result = GiveItem.run(conn0, sword_config(), data(remaining: 1))

      assert output_text(result) =~ "我这里有一把软剑，你拿去用吧。"

      assert_receive %Kalevala.Event{
        topic: "npc/inquiry_consume",
        data: %{count_key: "jian_count"}
      }, 200
    end
  end
end

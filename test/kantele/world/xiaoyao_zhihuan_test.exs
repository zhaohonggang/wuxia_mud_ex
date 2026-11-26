defmodule Kantele.World.XiaoyaoZhihuanTest do
  @moduledoc """
  逍遥派 #807：无崖子 ask_zhihuan（逍遥神仙环 / 掌门人信物）定向测试。

  LPC 依据：`kungfu/class/xiaoyao/wuyazi.c:605-654`。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.{NpcAskEvent, PlayerMeta, Stats, Vitals}
  alias Kantele.World.{InquiryHandlers, Items, Loader}

  setup_all do
    %{world: Loader.load()}
  end

  setup do
    Items.put("clone_lib:zhihuan", %ItemDef{
      id: "clone_lib:zhihuan",
      name: "逍遥神仙环",
      verbs: [],
      meta: %{aliases: ["shenxian huan", "zhihuan"]}
    })

    :ok
  end

  defp npc(world) do
    Enum.find(world.characters, fn c -> Enum.any?(c.meta.aliases || [], &(&1 == "wuya zi")) end)
  end

  defp player_conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp player(overrides \\ %{}) do
    base = %Kalevala.Character{
      id: "player:test",
      name: "测试玩家",
      room_id: "xiaoyao:shishi",
      inventory: [],
      meta: %PlayerMeta{
        family: %{name: "逍遥派", master_id: "npc:wuyazi"},
        stats: %Stats{skills: %{"zhemei_shou" => 200, "liuyang_zhang" => 0}},
        env: %{},
        temp: %{},
        vitals: %Vitals{qi: 100, max_qi: 100, jing: 100, max_jing: 100, neili: 100, max_neili: 100}
      }
    }

    Map.merge(base, overrides)
  end

  defp cfg(overrides \\ %{}) do
    %{
      "kind" => "xiaoyao_zhihuan",
      "item" => "clone_lib:zhihuan",
      "family" => "逍遥派",
      "master_id" => "true",
      "min_skill_levels_or" => %{"zhemei_shou" => 200, "liuyang_zhang" => 200},
      "family_deny" => "给我滚开！",
      "master_deny" => "你还不配！",
      "skill_deny" => "你拿去也没用。",
      "in_hand" => "本门的信物不就在你手中吗？",
      "not_here" => "你来晚了，逍遥神仙环现在不在我手中。",
      "same_family" => "逍遥神仙环现在落在本派{name}手中，你要用就去找他吧。",
      "other_family" => "我正为此事担忧呢，本门信物现在落入了{name}之手，你赶快去把他杀了，把指环取回来！",
      "vision_msg" => "$N微微一笑，道：“这逍遥神仙环你便拿去，希望日后你能继承我的衣钵。”"
    }
    |> Map.merge(overrides)
  end

  defp data(overrides \\ %{}) do
    %{
      kind: "xiaoyao_zhihuan",
      config: cfg(),
      npc_id: "npc:wuyazi",
      npc_name: "无崖子",
      npc_room_id: "xiaoyao:shishi",
      asker_id: "player:test",
      asker_name: "测试玩家"
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

  defp vision_text(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Event{data: %{text: text}}, _opts, _error_fun} -> text
      _ -> ""
    end)
    |> Enum.join("")
  end

  describe "UCL 数据落地" do
    test "两个问询键指向同一 xiaoyao_zhihuan 配置，无崖子携带信物", %{world: world} do
      wuyazi = npc(world)

      for key <- ["逍遥神仙环", "掌门人信物"] do
        inquiry = wuyazi.meta.inquiries[key]
        assert inquiry["kind"] == "xiaoyao_zhihuan"
        assert inquiry["item"] == "clone_lib:zhihuan"
        assert inquiry["min_skill_levels_or"] == %{"zhemei_shou" => 200, "liuyang_zhang" => 200}
        assert String.contains?(inquiry["other_family"], "把他杀了")
        refute String.contains?(inquiry["in_hand"], "\\n")
      end

      assert "clone_lib:zhihuan" in (wuyazi.meta.carry || [])
    end

    test "handler 已注册" do
      assert InquiryHandlers.lookup("xiaoyao_zhihuan") ==
               Kantele.World.InquiryHandlers.XiaoyaoZhihuan
    end
  end

  describe "NPC 侧持有者遍历" do
    test "提问者背包已有信物 -> owner=:asker", %{world: world} do
      ring = %{id: "inst:zhihuan", item_id: "clone_lib:zhihuan"}
      asker = player(%{inventory: [ring]})

      NpcAskEvent.call(player_conn(npc(world)), %Event{
        topic: "characters/ask",
        data: %{
          reply_to: self(),
          asker_id: asker.id,
          asker_name: asker.name,
          asker_inventory: asker.inventory,
          keyword: "逍遥神仙环"
        }
      })

      assert_receive %Event{topic: "npc/inquiry", data: %{owner: %{kind: :asker}}}
    end

    test "无提问者持有 -> owner=:npc（无崖子 create() 时把信物 move 给自己）", %{world: world} do
      NpcAskEvent.call(player_conn(npc(world)), %Event{
        topic: "characters/ask",
        data: %{
          reply_to: self(),
          asker_id: "player:test",
          asker_name: "测试玩家",
          asker_inventory: [],
          keyword: "掌门人信物"
        }
      })

      assert_receive %Event{topic: "npc/inquiry", data: %{owner: %{kind: :npc}}}
    end
  end

  describe "玩家侧门控与四支文案" do
    test "非本派 -> 给我滚开！" do
      other = player(%{meta: %{player().meta | family: %{name: "少林派", master_id: nil}}})

      conn =
        Kantele.World.InquiryHandlers.XiaoyaoZhihuan.run(
          player_conn(other),
          cfg(),
          data()
        )

      assert output_text(conn) =~ "给我滚开！"
    end

    test "非嫡传 -> 你还不配！" do
      other = player(%{meta: %{player().meta | family: %{name: "逍遥派", master_id: "other"}}})

      conn =
        Kantele.World.InquiryHandlers.XiaoyaoZhihuan.run(
          player_conn(other),
          cfg(),
          data()
        )

      assert output_text(conn) =~ "你还不配！"
    end

    test "折梅手/六阳掌均未达 200 -> 你拿去也没用。" do
      weak =
        player(%{
          meta: %{player().meta | stats: %Stats{skills: %{"zhemei_shou" => 199, "liuyang_zhang" => 0}}}
        })

      conn =
        Kantele.World.InquiryHandlers.XiaoyaoZhihuan.run(
          player_conn(weak),
          cfg(),
          data()
        )

      assert output_text(conn) =~ "你拿去也没用。"
    end

    test "本派门徒且折梅手 200 -> 信物在手/非角色对象/本派持有/外人四支逐字返回" do
      for {owner, expected} <- [
            {%{kind: :asker}, "本门的信物不就在你手中吗？"},
            {%{kind: :object}, "你来晚了，逍遥神仙环现在不在我手中。"},
            {%{kind: :character, name: "苏星河", family: "逍遥派"},
             "逍遥神仙环现在落在本派苏星河手中，你要用就去找他吧。"},
            {%{kind: :character, name: "丁春秋", family: "星宿派"},
             "我正为此事担忧呢，本门信物现在落入了丁春秋之手，你赶快去把他杀了，把指环取回来！"}
          ] do
        conn =
          Kantele.World.InquiryHandlers.XiaoyaoZhihuan.run(
            player_conn(player()),
            cfg(),
            data(%{owner: owner})
          )

        assert output_text(conn) =~ expected
      end
    end

    test "信物在无崖子手中 -> 发放 + 原文 message_vision" do
      conn =
        Kantele.World.InquiryHandlers.XiaoyaoZhihuan.run(
          player_conn(player()),
          cfg(),
          data(%{owner: %{kind: :npc, name: "无崖子"}})
        )

      granted = conn.private.update_character || conn.character
      assert Enum.any?(granted.inventory || [], &(&1.item_id == "clone_lib:zhihuan"))

      assert vision_text(conn) =~
               "无崖子微微一笑，道：“这逍遥神仙环你便拿去，希望日后你能继承我的衣钵。”"
    end
  end
end

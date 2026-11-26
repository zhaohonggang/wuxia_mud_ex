defmodule Kantele.World.InquiryHandlers.NpcItemGrantTest do
  @moduledoc """
  昆仑独特物品发放问询处理器测试（kind = "npc_item_grant"，#756）。

  对应 LPC：
  - `kungfu/class/kunlun/hetaichong.c` ask_jian / ask_jing
  - `kungfu/class/kunlun/hezudao.c` ask_jian / accept_object

  覆盖：
  - kind 注册
  - UCL 数据落地（何太冲/何足道 inquiries + carry + inquiry_state）
  - 门派门 / 师父门 / 技能 AND 门（含 per-skill 文案）/ 技能 OR 门 / 技能上限门
  - 持有发放（含 consume 回执 + broadcast + replacement equip 事件）
  - 未持有时回 no_item 文案
  - 两极剑归还（KunlunLiangjiAccept + GiveEvent.kunlun_liangji_return）
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.NpcItemGrant
  alias Kantele.World.Items

  setup do
    Items.put("clone_lib:liangjijian", %ItemDef{
      id: "clone_lib:liangjijian",
      name: "两极剑",
      verbs: [],
      meta: %{aliases: ["两极剑", "liangji jian"]}
    })

    Items.put("clone_lib:tieqin", %ItemDef{
      id: "clone_lib:tieqin",
      name: "铁琴剑",
      verbs: [],
      meta: %{aliases: ["铁琴剑", "tieqin jian"]}
    })

    Items.put("clone_lib:xunleijian", %ItemDef{
      id: "clone_lib:xunleijian",
      name: "「迅雷剑经」",
      verbs: [],
      meta: %{aliases: ["xunlei jianjing"]}
    })

    :ok
  end

  # ---------- conn / config / data 夹具 ----------

  defp conn(character) do
    %Conn{
      character: character,
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp vitals,
    do: %Vitals{qi: 100, max_qi: 100, jing: 100, max_jing: 100, neili: 100, max_neili: 100}

  defp player(overrides \\ %{}) do
    %Kalevala.Character{
      id: "player:test",
      name: "测试玩家",
      room_id: "kunlun:somewhere",
      inventory: [],
      meta: %PlayerMeta{
        family: %{name: "昆仑派", master_id: "kunlun_hezudao"},
        stats: %Stats{skills: %{}},
        env: %{},
        temp: %{},
        vitals: vitals()
      }
    }
    |> struct(overrides)
  end

  defp player_with_skills(skills, overrides \\ %{}) do
    stats = %Stats{skills: skills}

    player(%{
      meta: %PlayerMeta{
        family: %{name: "昆仑派", master_id: "kunlun_hezudao"},
        stats: stats,
        env: %{},
        temp: %{},
        vitals: vitals()
      }
    })
    |> struct(overrides)
  end

  defp data(overrides \\ %{}) do
    %{
      kind: "npc_item_grant",
      npc_id: "npc:test",
      npc_name: "何足道",
      npc_room_id: "kunlun:somewhere",
      npc_pid: nil,
      asker_id: "player:test",
      asker_name: "测试玩家",
      remaining: :infinity
    }
    |> Map.merge(overrides)
  end

  defp liangji_config(overrides \\ %{}) do
    %{
      "kind" => "npc_item_grant",
      "item" => "clone_lib:liangjijian",
      "npc_carry_key" => "clone_lib:liangjijian",
      "replacement_item" => "clone_lib:changjian",
      "match" => "两极剑",
      "family" => "昆仑派",
      "master_id" => true,
      "min_skill_levels" => %{"qiankun_jian" => 150},
      "min_skill_levels_or" => %{"tanqin_jifa" => 120, "chess" => 120},
      "success" => "既然这样，我这柄两极剑你就暂时拿去用吧。",
      "already" => "我的佩剑不正是你拿着在用吗，为何还反倒问起我来了？",
      "family_deny" => "阁下素来和本派并无渊源，何故来打听我的随身之物？",
      "master_deny" => "只有我的弟子才有资格使用我的随身宝剑，阁下还是请回吧。",
      "min_skill_deny" => "等你剑术大成之日，我自然不会吝惜佩剑，你再下去练练吧。",
      "min_skill_or_deny" => "你跟了我这么久，琴和棋却是这般…唉。",
      "no_item" => "你来晚了，我的两极剑现在并不在我手中。"
    }
    |> Map.merge(overrides)
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> data
      %Conn.EventText{text: %Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join("")
  end

  # ---------- 注册 + UCL 数据 ----------

  describe "注册与数据落地" do
    test "kind 已注册" do
      assert InquiryHandlers.lookup("npc_item_grant") == NpcItemGrant
    end

    test "何太冲 inquiries 含铁琴剑/剑经/迅雷剑经且为 npc_item_grant" do
      world = Kantele.World.Loader.load()
      npc = Enum.find(world.characters, &(&1.id == "clone_lib:kunlun_hetaichong"))

      # loader 用 hash id，按 aliases 定位
      npc = npc || Enum.find(world.characters, &("kunlun_hetaichong" in (&1.meta.aliases || [])))
      inq = npc.meta.inquiries

      for key <- ["铁琴剑", "剑经", "迅雷剑经"] do
        assert Map.get(inq, key)["kind"] == "npc_item_grant", "#{key} 未配置为 npc_item_grant"
      end

      assert Map.get(inq, "铁琴剑")["item"] == "clone_lib:tieqin"
      assert Map.get(inq, "铁琴剑")["allowed_master_ids"] == ["he zudao", "ban shuxian", "he taichong"]
      assert Map.get(inq, "剑经")["item"] == "clone_lib:xunleijian"
      assert "clone_lib:tieqin" in npc.meta.carry
      assert npc.meta.inquiry_state["tieqin_count"] == 1
    end

    test "何足道 inquiries 含两极剑（OR 技能门）+ 归还 accept 规则" do
      world = Kantele.World.Loader.load()
      npc = Enum.find(world.characters, &("kunlun_hezudao" in (&1.meta.aliases || [])))
      cfg = Map.get(npc.meta.inquiries, "两极剑")

      assert cfg["kind"] == "npc_item_grant"
      assert cfg["item"] == "clone_lib:liangjijian"
      assert cfg["master_id"] in [true, "true"]
      assert cfg["min_skill_levels"]["qiankun_jian"] == 150
      assert cfg["min_skill_levels_or"]["tanqin_jifa"] == 120
      assert cfg["min_skill_levels_or"]["chess"] == 120
      assert "clone_lib:liangjijian" in npc.meta.carry
      assert npc.meta.inquiry_state["liangji_count"] == 1

      assert Enum.any?(npc.meta.accept, &(&1.kind == "kunlun_liangji"))
    end

    test "迅雷剑经物品定义已落地（零信息丢失）" do
      world = Kantele.World.Loader.load()
      item = Enum.find(world.items, &(&1.id == "clone_lib:xunleijian"))
      assert item != nil
      assert item.name == "「迅雷剑经」"
      assert "xunlei jianjing" in (item.meta.aliases || [])
    end
  end

  # ---------- 门控 ----------

  describe "门控拒绝" do
    test "非昆仑派 → family_deny" do
      meta = %PlayerMeta{
        family: %{name: "少林派"},
        stats: %Stats{skills: %{}},
        env: %{},
        temp: %{},
        vitals: vitals()
      }
      c = conn(player(%{meta: meta}))
      c2 = NpcItemGrant.run(c, liangji_config(), data())
      assert String.contains?(output_text(c2), "阁下素来和本派并无渊源")
    end

    test "非嫡传 → master_deny" do
      meta = %PlayerMeta{
        family: %{name: "昆仑派", master_id: "other"},
        stats: %Stats{skills: %{}},
        env: %{},
        temp: %{},
        vitals: vitals()
      }
      c = conn(player(%{meta: meta}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao"}))
      assert String.contains?(output_text(c2), "只有我的弟子才有资格")
    end

    test "乾坤剑不足 → min_skill_deny" do
      c = conn(player_with_skills(%{"qiankun-jian" => 100, "chess" => 200}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao"}))
      assert String.contains?(output_text(c2), "等你剑术大成之日")
    end

    test "琴/棋均不足 → min_skill_or_deny" do
      c = conn(player_with_skills(%{"qiankun-jian" => 200, "tanqin-jifa" => 100, "chess" => 100}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao"}))
      assert String.contains?(output_text(c2), "你跟了我这么久，琴和棋却是这般")
    end

    test "琴或棋达标 → 通过 OR 门（发放）" do
      c = conn(player_with_skills(%{"qiankun-jian" => 200, "chess" => 150}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao"}))
      refute String.contains?(output_text(c2), "琴和棋却是这般")
      assert String.contains?(output_text(c2), "两极剑你就暂时拿去用")
    end

    test "per-skill 文案：昆仑剑不足用 kunlun_jian 专属文案" do
      cfg = %{
        "kind" => "npc_item_grant",
        "item" => "clone_lib:tieqin",
        "family" => "昆仑派",
        "min_skill_levels" => %{"kunlun_jian" => 150, "tanqin_jifa" => 100},
        "min_skill_denies" => %{
          "kunlun_jian" => "还不快给我滚回去用心练剑，少在这里罗嗦！",
          "tanqin_jifa" => "你连琴都弹不好，还用什么铁琴剑？"
        }
      }
      c = conn(player_with_skills(%{"kunlun-jian" => 100, "tanqin-jifa" => 200}))
      c2 = NpcItemGrant.run(c, cfg, data())
      assert String.contains?(output_text(c2), "还不快给我滚回去用心练剑")
    end

    test "技能上限门：迅雷剑法 > 120 → max_skill_deny" do
      cfg = %{
        "kind" => "npc_item_grant",
        "item" => "clone_lib:xunleijian",
        "family" => "昆仑派",
        "max_skill_levels" => %{"xunlei_jian" => 120},
        "max_skill_deny" => "你的迅雷剑法已经到这个地步，没必要再去参读剑经了。"
      }
      c = conn(player_with_skills(%{"xunlei-jian" => 150, "sword" => 100}))
      c2 = NpcItemGrant.run(c, cfg, data())
      assert String.contains?(output_text(c2), "没必要再去参读剑经了")
    end

    test "已持有 → already 文案" do
      inst = %{item_id: "clone_lib:liangjijian", id: "inst:1"}
      c = conn(player_with_skills(%{"qiankun-jian" => 200, "chess" => 150}, %{inventory: [inst]}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao"}))
      assert String.contains?(output_text(c2), "不正是你拿着在用吗")
    end

    test "NPC 不持有（remaining=0）→ no_item" do
      c = conn(player_with_skills(%{"qiankun-jian" => 200, "chess" => 150}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao", remaining: 0}))
      assert String.contains?(output_text(c2), "现在并不在我手中")
    end
  end

  # ---------- 发放副作用 ----------

  describe "发放副作用" do
    test "通过门控后发放物品并回 success 文案" do
      c = conn(player_with_skills(%{"qiankun-jian" => 200, "chess" => 150}))
      c2 = NpcItemGrant.run(c, liangji_config(), data(%{npc_id: "kunlun_hezudao"}))

      assert String.contains?(output_text(c2), "两极剑你就暂时拿去用")

      # give_item 走 put_character → private.update_character
      final_char = c2.private.update_character || c2.character
      assert Enum.any?(final_char.inventory, &(&1.item_id == "clone_lib:liangjijian"))
    end

    test "NPC 发剑后回发 inquiry_equip 事件装备替代长剑" do
      # 用一个真 pid 接收事件（当前进程），验证 npc/inquiry_equip 被正确投递
      parent = self()
      d = data(%{npc_id: "kunlun_hezudao", npc_pid: parent})

      c = conn(player_with_skills(%{"qiankun-jian" => 200, "chess" => 150}))
      NpcItemGrant.run(c, liangji_config(), d)

      assert_received %Kalevala.Event{topic: "npc/inquiry_equip", data: %{item_id: "clone_lib:changjian"}}
    end
  end

  # ---------- 两极剑归还 accept_object ----------

  describe "两极剑归还" do
    test "KunlunLiangjiAccept 命中两极剑 → 发 kunlun/liangji_return 事件" do
      parent = self()

      npc = %Kalevala.Character{
        id: "kunlun_hezudao",
        name: "何足道",
        inventory: [],
        meta: %Kantele.Character.NonPlayerMeta{}
      }
      c = conn(npc)
      inst = %{item_id: "clone_lib:liangjijian", id: "inst:liangji"}

      Kantele.World.KunlunLiangjiAccept.handle(c, npc, inst, %{reply_to: parent, from_id: "player:test"}, "测试玩家")

      assert_received %Kalevala.Event{
        topic: "kunlun/liangji_return",
        data: %{item_id: "clone_lib:liangjijian", instance_id: "inst:liangji"}
      }
    end

    test "嫡传归还 → 销毁物品 + 「很好，很好！」" do
      inst = %{item_id: "clone_lib:liangjijian", id: "inst:liangji"}
      c = conn(player_with_skills(%{}, %{inventory: [inst]}))

      c2 = Kantele.Character.GiveEvent.kunlun_liangji_return(
        c,
        %{data: %{item_id: "clone_lib:liangjijian", instance_id: "inst:liangji", from_id: "player:test"}}
      )

      assert String.contains?(output_text(c2), "很好，很好！")
      final_char = c2.private.update_character || c2.character
      refute Enum.any?(final_char.inventory, &(&1.id == "inst:liangji"))
    end

    test "非嫡传归还 → 「多谢这位...将我的宝剑交回」" do
      inst = %{item_id: "clone_lib:liangjijian", id: "inst:liangji"}

      meta = %PlayerMeta{
        family: %{name: "昆仑派", master_id: "other"},
        stats: %Stats{skills: %{}},
        env: %{},
        temp: %{},
        vitals: vitals()
      }
      c = conn(player(%{meta: meta, inventory: [inst]}))

      c2 = Kantele.Character.GiveEvent.kunlun_liangji_return(
        c,
        %{data: %{item_id: "clone_lib:liangjijian", instance_id: "inst:liangji", from_id: "player:test"}}
      )

      assert String.contains?(output_text(c2), "将我的宝剑交回")
      final_char = c2.private.update_character || c2.character
      refute Enum.any?(final_char.inventory, &(&1.id == "inst:liangji"))
    end
  end
end

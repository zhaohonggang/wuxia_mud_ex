defmodule Kantele.World.InquiryHandlersQuestLilianTest do
  @moduledoc """
  #813 QUEST_D->accept_ask("历练"/"历炼"/"锻炼")：丁春秋门派历练流程。

  LPC `adm/daemons/questd.c:398-468` 的门序、正/邪/中立三分支、message_sort
  三视角、地图册提示、out_family 标记与 rumor 均需逐条落地。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.QuestLilian
  alias Kantele.World.Loader

  @config %{
    "kind" => "quest_lilian",
    "family" => "星宿派",
    "npc_shen" => 0,
    "npc_shen_type" => -1,
    "min_combat_exp" => 50_000,
    "min_score" => 100,
    "family_deny" => "你是谁？找我有什么事情么？",
    "out_family_deny" => "去吧！{name}，好自为之！",
    "exp_deny" => "{npc}叹了一口气，看了看{name}道：你的武功基础还不太好，还是再好好锻炼吧。",
    "score_deny" => "{npc}摆摆手道：你的江湖阅历太少，现在不可外出独自行走江湖。",
    "good_msg" => "{npc}对{name}欣慰的点了点头，道：看来我们{family}又出了一位人才啊！",
    "bad_msg" => "{npc}对{name}哈哈大笑道：好！好！好！你可以出去走走看看了！",
    "neutral_msg" => "{npc}对{name}叮嘱道：以后你行走江湖常常是孤身一人！",
    "map_msg" => "{npc}翻出一本小册子，对{name}道：今后你行走江湖，许多山川地理都可以记录。",
    "map_got" => "你获得了师傅赠给你的地图册。",
    "map_help" => "请参见帮助(help quest)以获得更详细的信息。",
    "rumor" => "听说{name}已经开始闯荡江湖。"
  }

  defp conn(opts \\ []) do
    stats = %Stats{
      combat_exp: Keyword.get(opts, :combat_exp, 400_000),
      score: Keyword.get(opts, :score, 500),
      shen: -30_000
    }

    env =
      case Keyword.get(opts, :out_family, false) do
        true -> %{out_family: 1}
        _ -> %{}
      end

    %Conn{
      character: %Character{
        id: "player:test",
        name: "李四",
        room_id: "xiyu:riyuedong",
        meta: %PlayerMeta{
          vitals: Vitals.new(),
          stats: stats,
          env: env,
          family: %{name: Keyword.get(opts, :family, "星宿派")}
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: Keyword.get(opts, :asker_id, "player:test"),
      asker_name: Keyword.get(opts, :asker_name, "李四"),
      npc_id: "xingxiu_ding_hash",
      npc_name: Keyword.get(opts, :npc_name, "丁春秋"),
      npc_room_id: Keyword.get(opts, :npc_room_id, "xiyu:riyuedong"),
      npc_family: Keyword.get(opts, :npc_family, "星宿派")
    }
  end

  # prompt 渲染的是 Conn.EventText（状态条），这里只收集 handler 自己 render 的正文。
  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: text} -> [text]
      _ -> []
    end)
    |> Enum.join()
  end

  defp publishes(conn) do
    Enum.filter(conn.private.channel_changes, fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
  end

  defp updated(conn) do
    case conn.private do
      %{update_character: character} when not is_nil(character) -> character
      _ -> conn.character
    end
  end

  test "quest_lilian 已注册，且与张无忌任务 spec 的 quest 是两套机制" do
    assert InquiryHandlers.lookup("quest_lilian") == QuestLilian
    assert InquiryHandlers.lookup("quest") != QuestLilian
  end

  test "非问询者本人完全沉默" do
    result = QuestLilian.run(conn(), @config, data(asker_id: "player:other"))
    assert output_text(result) == ""
    assert publishes(result) == []
  end

  test "门派不符：只回原文拒绝，不设 out_family" do
    result = QuestLilian.run(conn(family: "少林派"), @config, data())
    assert output_text(result) =~ "你是谁？找我有什么事情么？"
    refute updated(result).meta.env[:out_family]
    assert publishes(result) == []
  end

  test "已有 out_family：回玩家名原文，不重复赠册" do
    result = QuestLilian.run(conn(out_family: true), @config, data())
    assert output_text(result) == "去吧！李四，好自为之！"
    assert publishes(result) == []
  end

  test "combat_exp < 50000：NPC 叹气 vision，不设 out_family" do
    result = QuestLilian.run(conn(combat_exp: 49_999), @config, data())
    assert output_text(result) == ""
    assert [{:publish, channel, event, _, _}] = publishes(result)
    assert channel == "rooms:xiyu:riyuedong"
    assert event.data.text =~ "丁春秋"
    assert event.data.text =~ "李四"
    assert event.data.text =~ "你的武功基础还不太好"
    refute updated(result).meta.env[:out_family]
  end

  test "score < 100：NPC 摆手 vision，不设 out_family" do
    result = QuestLilian.run(conn(score: 99), @config, data())
    assert [{:publish, _, event, _, _}] = publishes(result)
    assert event.data.text =~ "你的江湖阅历太少"
    refute updated(result).meta.env[:out_family]
  end

  test "邪派分支：message_sort 三视角 + 地图册提示 + out_family 落库" do
    result = QuestLilian.run(conn(), @config, data())
    text = output_text(result)

    assert text =~ "丁春秋对你哈哈大笑道：好！好！好！你可以出去走走看看了！"
    assert text =~ "丁春秋翻出一本小册子，对你道：今后你行走江湖"
    assert text =~ "你获得了师傅赠给你的地图册。"
    assert text =~ "请参见帮助(help quest)以获得更详细的信息。"

    broadcasts = publishes(result)
    assert length(broadcasts) == 2

    bad = Enum.find(broadcasts, fn {:publish, _, event, _, _} -> event.data.text =~ "哈哈大笑" end)
    map = Enum.find(broadcasts, fn {:publish, _, event, _, _} -> event.data.text =~ "小册子" end)

    assert {:publish, _, bad_event, bad_opts, _} = bad
    assert {:publish, _, map_event, map_opts, _} = map
    assert bad_event.data.text =~ "丁春秋对李四哈哈大笑道"
    assert map_event.data.text =~ "丁春秋翻出一本小册子，对李四道"
    assert bad_opts[:meta][:exclude_actor] == true
    assert map_opts[:meta][:exclude_actor] == true

    assert updated(result).meta.env[:out_family] == 1
  end

  test "正派分支：shen_type=1 走欣慰文案并把门派名嵌入我们{family}" do
    config = Map.put(@config, "npc_shen_type", 1)
    result = QuestLilian.run(conn(), config, data())
    assert output_text(result) =~ "丁春秋对你欣慰的点了点头，道：看来我们星宿派又出了一位人才啊！"
    assert updated(result).meta.env[:out_family] == 1
  end

  test "中立分支：shen/shen_type 均未越界走叮嘱文案" do
    config = @config |> Map.put("npc_shen", 0) |> Map.put("npc_shen_type", 0)
    result = QuestLilian.run(conn(), config, data())
    assert output_text(result) =~ "丁春秋对你叮嘱道：以后你行走江湖常常是孤身一人！"
    assert updated(result).meta.env[:out_family] == 1
  end

  test "shen 原值也能定正邪：shen > 500 / shen < -500 与 shen_type 等价" do
    good = QuestLilian.run(conn(), Map.put(@config, "npc_shen", 501), data())
    bad = QuestLilian.run(conn(), Map.put(@config, "npc_shen", -501), data())

    assert output_text(good) =~ "欣慰的点了点头"
    assert output_text(bad) =~ "哈哈大笑道"
  end

  test "clone_lib 丁春秋三键全部落 quest_lilian 配置，阈值与三分支文案齐全" do
    world = Loader.load()
    npc = Enum.find(world.characters, &(&1.name == "丁春秋"))
    assert npc

    for key <- ["历练", "历炼", "锻炼"] do
      config = Map.get(npc.meta.inquiries, key)
      assert is_map(config), "#{key} 应为配置 map"
      assert (config["kind"] || config[:kind]) == "quest_lilian"
      assert (config["family"] || config[:family]) == "星宿派"
      assert (config["min_combat_exp"] || config[:min_combat_exp]) == 50_000
      assert (config["min_score"] || config[:min_score]) == 100
      assert String.contains?(config["bad_msg"], "自认所谓大侠之辈")
      assert String.contains?(config["map_msg"], "地图册")
    end
  end

  test "clone_lib 莫大三键全部落 quest_lilian 配置，门派为衡山派且为正派分支" do
    world = Loader.load()
    npc = Enum.find(world.characters, &(&1.name == "莫大"))
    assert npc

    for key <- ["历练", "历炼", "锻炼"] do
      config = Map.get(npc.meta.inquiries, key)
      assert is_map(config), "#{key} 应为配置 map"
      assert (config["kind"] || config[:kind]) == "quest_lilian"
      assert (config["family"] || config[:family]) == "衡山派"
      assert (config["npc_shen_type"] || config[:npc_shen_type]) == 1
      assert (config["min_combat_exp"] || config[:min_combat_exp]) == 50_000
      assert (config["min_score"] || config[:min_score]) == 100
      assert String.contains?(config["good_msg"], "欣慰")
      assert String.contains?(config["map_got"], "地图册")
    end
  end
end

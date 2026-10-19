defmodule Kantele.Character.NpcScriptEventTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.NpcScriptEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  describe "脚本化问询分发（NpcAskEvent）" do
    test "give 脚本 → npc/give 事件回玩家" do
      npc = npc(%{"铸剑" => %{"reply" => "收好这块精钢。\n", "give" => "signature:jinggang"}})

      conn = NpcAskEvent.call(build_conn(npc), ask_event("铸剑"))

      assert conn != nil

      assert_receive %Event{
        topic: "npc/give",
        data: %{npc_name: "干将", item_id: "signature:jinggang", asker_id: "player-1"}
      }
    end

    test "learn_skill 脚本 → npc/learn 事件" do
      npc = npc(%{"道法" => %{"reply" => "且听。\n", "learn_skill" => "taoism"}})

      NpcAskEvent.call(build_conn(npc), ask_event("道法"))

      assert_receive %Event{
        topic: "npc/learn",
        data: %{skill: "taoism", asker_id: "player-1"}
      }
    end

    test "family 脚本 → npc/faction 事件（带 gongxian）" do
      npc = npc(%{"拜师" => %{"reply" => "入门吧。\n", "family" => "青阳门", "gongxian" => 10}})

      NpcAskEvent.call(build_conn(npc), ask_event("拜师"))

      assert_receive %Event{
        topic: "npc/faction",
        data: %{family: "青阳门", gongxian: 10, asker_id: "player-1"}
      }
    end

    test "perform 脚本 → npc/perform 事件（带配置与 NPC 门派，供玩家侧校验）" do
      npc = %{
        npc(%{"绝户神抓" => %{"perform_id" => "huzhua-shou/juehu", "min_gongxian" => 400}})
        | meta: %Kantele.Character.NonPlayerMeta{
            inquiries: %{"绝户神抓" => %{"perform_id" => "huzhua-shou/juehu", "min_gongxian" => 400}},
            teach: %{family: "武当派", teach_skills: %{}, no_teach: []}
          }
      }

      NpcAskEvent.call(build_conn(npc), ask_event("绝户神抓"))

      assert_receive %Event{
        topic: "npc/perform",
        data: %{perform_id: "huzhua-shou/juehu", npc_family: "武当派", asker_id: "player-1"}
      }
    end

    test "纯文本问询保持原有行为（不进脚本分支）" do
      npc = npc(%{"莫邪" => "她是吾妻。\n"})

      NpcAskEvent.call(build_conn(npc), ask_event("莫邪"))

      refute_receive %Event{topic: "npc/give"}, 100
      refute_receive %Event{topic: "npc/learn"}, 100
      refute_receive %Event{topic: "npc/faction"}, 100
    end
  end

  describe "库存型问询分发（NpcAskEvent → npc/inquiry）" do
    test "kind 脚本 → 回执 kind/配置/当前库存" do
      inquiries = %{
        "铁护腕" => %{
          "kind" => "give_item",
          "item" => "shaolin:huwan",
          "count" => "huju_count"
        }
      }

      npc = %{
        npc(inquiries)
        | meta: %Kantele.Character.NonPlayerMeta{
            inquiries: inquiries,
            inquiry_state: %{"huju_count" => 3}
          }
      }

      NpcAskEvent.call(build_conn(npc), ask_event("铁护腕"))

      assert_receive %Event{
        topic: "npc/inquiry",
        data: %{
          kind: "give_item",
          remaining: 3,
          npc_name: "干将",
          asker_id: "player-1",
          config: %{"item" => "shaolin:huwan"}
        }
      }
    end

    test "未配置 count 时库存为 :infinity" do
      inquiries = %{"铁护腕" => %{"kind" => "give_item", "item" => "shaolin:huwan"}}

      NpcAskEvent.call(build_conn(npc(inquiries)), ask_event("铁护腕"))

      assert_receive %Event{topic: "npc/inquiry", data: %{remaining: :infinity}}
    end
  end

  describe "玩家侧库存问询（NpcScriptEvent.npc/inquiry）" do
    setup do
      Items.put("shaolin:huwan", %Item{
        id: "shaolin:huwan",
        name: "铁护腕",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 100, value: 100}
      })

      Items.put("shaolin:weibo", %Item{
        id: "shaolin:weibo",
        name: "皮围脖",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 100, value: 100}
      })

      Items.put("shaolin:beixin", %Item{
        id: "shaolin:beixin",
        name: "铁背心",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 100, value: 100}
      })

      :ok
    end

    test "背包没有 → 发放、渲染返回值并回执扣库存" do
      conn = NpcScriptEvent.inquiry_result(build_conn(player()), inquiry_event(give_config()))

      character = conn.private.update_character
      assert Enum.any?(character.inventory, &(&1.item_id == "shaolin:huwan"))
      assert output_text(conn) =~ "拿去吧。"
      assert_receive %Event{topic: "npc/inquiry_consume", data: %{count_key: "huju_count"}}
    end

    test "背包已有 → 不发放，回已有文案" do
      instance = %Item.Instance{
        id: "instance-1",
        item_id: "shaolin:huwan",
        created_at: DateTime.utc_now()
      }

      character = %{player() | inventory: [instance]}
      conn = NpcScriptEvent.inquiry_result(build_conn(character), inquiry_event(give_config()))

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "你现在身上不是有这样防具吗"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100
    end

    test "皮围脖按 item_id 尾段识别（别名表没有 weibo）" do
      instance = %Item.Instance{
        id: "instance-2",
        item_id: "shaolin:weibo",
        created_at: DateTime.utc_now()
      }

      character = %{player() | inventory: [instance]}

      config =
        Map.merge(give_config(), %{
          "item" => "shaolin:weibo",
          "match" => "weibo"
        })

      conn = NpcScriptEvent.inquiry_result(build_conn(character), inquiry_event(config))

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "你现在身上不是有这样防具吗"
    end

    test "unique = \"false\" 时不查重（铁背心可再要）" do
      instance = %Item.Instance{
        id: "instance-3",
        item_id: "shaolin:beixin",
        created_at: DateTime.utc_now()
      }

      character = %{player() | inventory: [instance]}

      config =
        Map.merge(give_config(), %{
          "item" => "shaolin:beixin",
          "match" => "beixin",
          "count" => "beixin_count",
          "unique" => "false"
        })

      conn = NpcScriptEvent.inquiry_result(build_conn(character), inquiry_event(config))

      character = conn.private.update_character
      assert Enum.count(character.inventory, &(&1.item_id == "shaolin:beixin")) == 2
      assert output_text(conn) =~ "拿去吧。"
      assert_receive %Event{topic: "npc/inquiry_consume", data: %{count_key: "beixin_count"}}
    end

    test "库存耗尽 → 不发放，回发完文案" do
      conn =
        NpcScriptEvent.inquiry_result(
          build_conn(player()),
          inquiry_event(give_config(), remaining: 0)
        )

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "防具已经发完了"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100
    end

    test "门派不符 → 不发放，回拒答文案" do
      config = Map.put(give_config(), "family", "少林派")
      conn = NpcScriptEvent.inquiry_result(build_conn(player()), inquiry_event(config))

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "与本派素无来往"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100
    end
  end

  describe "NPC 侧库存扣减（npc/inquiry_consume）" do
    test "收到回执后自减" do
      conn =
        NpcAskEvent.inquiry_consume(
          build_conn(npc_with_state(3)),
          %Event{topic: "npc/inquiry_consume", data: %{count_key: "huju_count"}}
        )

      assert conn.private.update_character.meta.inquiry_state["huju_count"] == 2
    end

    test "库存到 0 后不再减成负数" do
      conn =
        NpcAskEvent.inquiry_consume(
          build_conn(npc_with_state(0)),
          %Event{topic: "npc/inquiry_consume", data: %{count_key: "huju_count"}}
        )

      assert conn.private.update_character.meta.inquiry_state["huju_count"] == 0
    end
  end

  describe "玩家侧领物（NpcScriptEvent.npc/give）" do
    setup do
      Items.put("signature:jinggang", %Item{
        id: "signature:jinggang",
        name: "精钢块 Steel Ingot",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 100, value: 500}
      })

      :ok
    end

    test "给物入背包并渲染回话" do
      conn = NpcScriptEvent.give_result(build_conn(player()), give_event())

      updated = conn.private.update_character || conn.character

      assert [%Item.Instance{item_id: "signature:jinggang"}] = updated.inventory
      assert output_text(conn) =~ "递到你手中"
    end

    test "它人领物事件不处理" do
      event = %{give_event() | data: %{give_event().data | asker_id: "someone"}}
      conn = NpcScriptEvent.give_result(build_conn(player()), event)

      assert conn.private.update_character == nil
    end
  end

  describe "玩家侧传技（NpcScriptEvent.npc/learn）" do
    test "学会新技能（stats.skills 首学 1 级）" do
      conn = NpcScriptEvent.learn_result(build_conn(player()), learn_event())

      updated = conn.private.update_character || conn.character

      assert updated.meta.stats.skills["taoism"] == 1
      assert output_text(conn) =~ "领悟了「taoism」"
    end
  end

  describe "玩家侧拜师（NpcScriptEvent.npc/faction）" do
    test "写入 family 并发放门派贡献" do
      conn = NpcScriptEvent.faction_result(build_conn(player()), faction_event())

      updated = conn.private.update_character || conn.character

      assert updated.meta.family.name == "青阳门"
      assert updated.meta.stats.gongxian == 10
      assert output_text(conn) =~ "青阳门"
    end
  end

  describe "玩家侧授绝招（NpcScriptEvent.npc/perform）" do
    test "全门槛达标：学会绝招并扣门派贡献" do
      p =
        player(
          stats: %{
            skills: %{"huzhua-shou" => 120, "force" => 180},
            gongxian: 500,
            shen: 100_000,
            performs: MapSet.new()
          }
        )

      conn = NpcScriptEvent.perform_result(build_conn(p), perform_event())
      updated = conn.private.update_character || conn.character

      assert MapSet.member?(updated.meta.stats.performs, "huzhua-shou/juehu")
      assert updated.meta.stats.gongxian == 100
      assert output_text(conn) =~ "学会了「huzhua-shou/juehu」"
    end

    test "门槛不过（贡献不足）：不落盘并提示" do
      p =
        player(
          stats: %{
            skills: %{"huzhua-shou" => 120, "force" => 180},
            gongxian: 10,
            shen: 100_000
          }
        )

      conn = NpcScriptEvent.perform_result(build_conn(p), perform_event())

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "效力还不够"
    end

    test "非同门：拒绝授招（读玩家 meta.family）" do
      p =
        player(
          stats: %{
            skills: %{"huzhua-shou" => 120, "force" => 180},
            gongxian: 500,
            shen: 100_000
          },
          family: %{name: "青阳门"}
        )

      conn = NpcScriptEvent.perform_result(build_conn(p), perform_event())

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "并非同门"
    end

    test "它人事件不处理" do
      event = %{perform_event() | data: %{perform_event().data | asker_id: "someone"}}
      conn = NpcScriptEvent.perform_result(build_conn(player()), event)

      assert conn.private.update_character == nil
    end
  end

  # ---- helpers ----

  defp npc(inquiries) do
    %Kalevala.Character{
      id: "signature:ganjiang",
      name: "干将",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.NonPlayerMeta{inquiries: inquiries}
    }
  end

  defp ask_event(keyword),
    do: %Event{
      topic: "characters/ask",
      data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: keyword}
    }

  defp give_event(),
    do: %Event{
      topic: "npc/give",
      data: %{npc_name: "干将", item_id: "signature:jinggang", asker_id: "player-1"}
    }

  defp learn_event(),
    do: %Event{
      topic: "npc/learn",
      data: %{npc_name: "青阳子", skill: "taoism", asker_id: "player-1"}
    }

  defp faction_event(),
    do: %Event{
      topic: "npc/faction",
      data: %{npc_name: "青阳子", family: "青阳门", gongxian: 10, asker_id: "player-1"}
    }

  defp perform_event() do
    %Event{
      topic: "npc/perform",
      data: %{
        npc_name: "俞莲舟",
        npc_family: "武当派",
        asker_id: "player-1",
        config: %{
          "perform_id" => "huzhua-shou/juehu",
          "skill" => "huzhua-shou",
          "min_levels" => %{"force" => 180, "huzhua-shou" => 120},
          "min_gongxian" => 400,
          "min_shen" => 100_000,
          "cost_gongxian" => 400
        }
      }
    }
  end

  defp npc_with_state(count) do
    %{
      npc(%{})
      | meta: %Kantele.Character.NonPlayerMeta{
          inquiries: %{},
          inquiry_state: %{"huju_count" => count}
        }
    }
  end

  defp inquiry_event(config, opts \\ []) do
    %Event{
      topic: "npc/inquiry",
      from_pid: self(),
      data: %{
        kind: "give_item",
        config: config,
        npc_name: "武修文",
        npc_pid: self(),
        npc_room_id: "test:room",
        asker_id: "player-1",
        asker_name: "张三",
        remaining: Keyword.get(opts, :remaining, :infinity)
      }
    }
  end

  defp give_config do
    %{
      "kind" => "give_item",
      "item" => "shaolin:huwan",
      "match" => "huwan",
      "count" => "huju_count",
      "unique" => true,
      "success" => "拿去吧。",
      "already" => "你现在身上不是有这样防具吗，怎麽又来要了？ 真是贪得无餍！",
      "exhausted" => "抱歉，你来得不是时候，防具已经发完了。"
    }
  end

  defp player(opts \\ []) do
    stats = struct(Stats.new(), Keyword.get(opts, :stats, %{}))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        family: Keyword.get(opts, :family)
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end

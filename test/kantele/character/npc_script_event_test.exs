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

    test "闭包字面量问询不回显原文（未实现占位）" do
      npc = npc(%{"苗人凤" => "(: ask_me :)"})

      conn = NpcAskEvent.call(build_conn(npc), ask_event("苗人凤"))

      assert conn != nil
      # 未实现闭包不应向玩家发任何 tell：channel_changes 保持空
      assert conn.private.channel_changes == []
      refute_receive %Event{topic: "npc/give"}, 100
      refute_receive %Event{topic: "npc/learn"}, 100
      refute_receive %Event{topic: "npc/faction"}, 100
    end

    test "普通文本问询正常回显到玩家频道" do
      npc = npc(%{"莫邪" => "她是吾妻。\n"})

      conn = NpcAskEvent.call(build_conn(npc), ask_event("莫邪"))

      publishes =
        Enum.filter(conn.private.channel_changes, fn
          {:publish, "characters:player-1", _, _, _} -> true
          _ -> false
        end)

      assert length(publishes) == 1
      refute_receive %Event{topic: "npc/give"}, 100
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

      Items.put("clone_lib:baguadao", %Item{
        id: "clone_lib:baguadao",
        name: "紫金八卦刀",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 1000, value: 5000}
      })

      Items.put("clone_lib:sjmletter", %Item{
        id: "clone_lib:sjmletter",
        name: "天刀八势信",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 50, value: 0}
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

    test "杀气上限（五毒 ask_me shen > -10000 拒）" do
      config =
        Map.merge(give_config(), %{
          "max_shen" => -10_000,
          "max_shen_deny" => "你是怎么搞的？连杀人都不会？"
        })

      denied =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{shen: -9_999})),
          inquiry_event(config)
        )

      assert denied.private.update_character == nil
      assert output_text(denied) =~ "连杀人都不会"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      # 恰好 -10000 可通过（LPC `shen > -10000` 才拒）
      allowed =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{shen: -10_000})),
          inquiry_event(config)
        )

      assert Enum.any?(
               allowed.private.update_character.inventory,
               &(&1.item_id == "shaolin:huwan")
             )
    end

    test "经验下限（五毒 ask_me combat_exp < 100000 拒）" do
      config =
        Map.merge(give_config(), %{
          "min_combat_exp" => 100_000,
          "min_exp_deny" => "你现在经验太浅，不用忙着去阅读毒经。"
        })

      denied =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{combat_exp: 99_999})),
          inquiry_event(config)
        )

      assert denied.private.update_character == nil
      assert output_text(denied) =~ "经验太浅"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      allowed =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{combat_exp: 100_000})),
          inquiry_event(config)
        )

      assert Enum.any?(
               allowed.private.update_character.inventory,
               &(&1.item_id == "shaolin:huwan")
             )
    end

    test "技能上限（五毒 ask_me poison > 119 拒）" do
      config =
        Map.merge(give_config(), %{
          "max_skill_levels" => %{"poison" => 119},
          "max_skill_deny" => "你用毒的造诣已经不浅了，这毒经不看也罢。"
        })

      denied =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{skills: %{"poison" => 120}})),
          inquiry_event(config)
        )

      assert denied.private.update_character == nil
      assert output_text(denied) =~ "造诣已经不浅"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      allowed =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{skills: %{"poison" => 119}})),
          inquiry_event(config)
        )

      assert Enum.any?(
               allowed.private.update_character.inventory,
               &(&1.item_id == "shaolin:huwan")
             )
    end

    # ---- 新增门控（P5-4ay 商剑鸣 item_grant）----

    test "技能下限（紫金八卦刀 bagua_dao < 150 拒）" do
      config =
        Map.merge(give_config(), %{
          "item" => "clone_lib:baguadao",
          "match" => "baguadao",
          "min_skill_levels" => %{"bagua_dao" => 150},
          "min_skill_deny" => "你连八卦刀法都没学好，就算宝刀在手也是白搭。"
        })

      denied =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{skills: %{"bagua_dao" => 140}})),
          inquiry_event(config)
        )

      assert denied.private.update_character == nil
      assert output_text(denied) =~ "白搭"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      allowed =
        NpcScriptEvent.inquiry_result(
          build_conn(player(stats: %{skills: %{"bagua_dao" => 150}})),
          inquiry_event(config)
        )

      assert Enum.any?(
               allowed.private.update_character.inventory,
               &(&1.item_id == "clone_lib:baguadao")
             )
    end

    test "杀气上限且非本师弟子（紫金八卦刀 shen > -50000 / master_id 拒）" do
      config =
        Map.merge(give_config(), %{
          "item" => "clone_lib:baguadao",
          "match" => "baguadao",
          "unique" => true,
          "family" => "商家堡",
          "master_id" => true,
          "max_shen" => -50_000,
          "max_shen_deny" => "像你这样的心慈手软之辈，这刀你不用也罢。",
          "master_deny" => "只有我的弟子才配用这八卦刀，你别拿去丢脸。"
        })

      # 杀气过高（shen > -50000），门派匹配但杀气不够
      denied_shen =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{shen: -49_999},
              family: %{name: "商家堡", master_id: "signature:shang_ming"}
            )
          ),
          inquiry_event(config)
        )

      assert denied_shen.private.update_character == nil
      assert output_text(denied_shen) =~ "不用也罢"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      # 杀气达标但非本师弟子（family/master_id != npc_id）
      denied_master =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{shen: -60_000},
              family: %{name: "商家堡", master_id: "other:npc"}
            )
          ),
          inquiry_event(config)
        )

      assert denied_master.private.update_character == nil
      assert output_text(denied_master) =~ "别拿去丢脸"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      # 本师弟子且杀气达标 → 发放
      allowed =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{shen: -60_000},
              family: %{name: "商家堡", master_id: "signature:shang_ming"}
            )
          ),
          inquiry_event(config)
        )

      assert Enum.any?(
               allowed.private.update_character.inventory,
               &(&1.item_id == "clone_lib:baguadao")
             )
      assert output_text(allowed) =~ "拿去吧"
    end

    test "天刀八势：min_gongxian / max_neili / min_skill_levels 门控（不足则拒）" do
      config =
        Map.merge(give_config(), %{
          "item" => "clone_lib:sjmletter",
          "match" => "sjmletter",
          "unique" => true,
          "family" => "商家堡",
          "min_gongxian" => 2200,
          "max_neili" => 3200,
          "min_skill_levels" => %{
            "bagua_dao" => 200,
            "wai_bagua" => 200,
            "nei_bagua" => 200
          },
          "min_gongxian_deny" => "你在镖局内碌碌无为，这一招我暂时还不能传你。",
          "max_neili_deny" => "你的内力修为不足，施展不出这招。",
          "min_skill_deny" => "你的八卦刀法还练得不到家，自己下去练练再来吧！"
        })

      # 贡献不足（技能已达标，避免被 min_skill 先拦）
      denied_gongxian =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{
                gongxian: 2199,
                skills: %{"bagua_dao" => 200, "wai_bagua" => 200, "nei_bagua" => 200}
              },
              family: %{name: "商家堡"}
            )
          ),
          inquiry_event(config)
        )

      assert denied_gongxian.private.update_character == nil
      assert output_text(denied_gongxian) =~ "碌碌无为"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      # 内力上限不足（技能、贡献均达标）
      denied_neili =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{
                gongxian: 2200,
                skills: %{"bagua_dao" => 200, "wai_bagua" => 200, "nei_bagua" => 200}
              },
              vitals: %{max_neili: 3199},
              family: %{name: "商家堡"}
            )
          ),
          inquiry_event(config)
        )

      assert denied_neili.private.update_character == nil
      assert output_text(denied_neili) =~ "内力修为不足"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100

      # 技能不足
      denied_skill =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(stats: %{skills: %{"bagua_dao" => 199}}, family: %{name: "商家堡"})
          ),
          inquiry_event(config)
        )

      assert denied_skill.private.update_character == nil
      assert output_text(denied_skill) =~ "练练再来吧"
      refute_receive %Event{topic: "npc/inquiry_consume"}, 100
    end

    test "天刀八势：全部达标则赠信并习得绝招、扣贡献（perform_id + cost_gongxian）" do
      config =
        Map.merge(give_config(), %{
          "item" => "clone_lib:sjmletter",
          "match" => "sjmletter",
          "unique" => true,
          "family" => "商家堡",
          "perform_id" => "bagua-dao/tian",
          "cost_gongxian" => 2200,
          "min_gongxian" => 2200,
          "max_neili" => 3200,
          "min_skill_levels" => %{
            "bagua_dao" => 200,
            "wai_bagua" => 200,
            "nei_bagua" => 200
          },
          "maxed" => "你不是已经会了吗？",
          "success" => "现在我就修书一封，你送到镇远镖局总镖头王维扬处，他自会传你绝技！"
        })

      conn =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{
                gongxian: 2200,
                skills: %{"bagua_dao" => 200, "wai_bagua" => 200, "nei_bagua" => 200}
              },
              vitals: %{max_neili: 3200},
              family: %{name: "商家堡", master_id: "signature:shang_ming"}
            )
          ),
          inquiry_event(config)
        )

      character = conn.private.update_character

      # 信入背包
      assert Enum.any?(character.inventory, &(&1.item_id == "clone_lib:sjmletter"))
      # 习得绝招（perform_id 持久化到 stats.performs）
      assert character.meta.stats.performs |> MapSet.member?("bagua-dao/tian")
      # 扣贡献
      assert character.meta.stats.gongxian == 0
      assert output_text(conn) =~ "绝技"
    end

    test "perform_id 已习得 → maxed 文案，不重复发放" do
      config =
        Map.merge(give_config(), %{
          "item" => "clone_lib:sjmletter",
          "match" => "sjmletter",
          "unique" => true,
          "family" => "商家堡",
          "perform_id" => "bagua-dao/tian",
          "maxed" => "你不是已经会了吗？"
        })

      conn =
        NpcScriptEvent.inquiry_result(
          build_conn(
            player(
              stats: %{gongxian: 3000, performs: MapSet.new(["bagua-dao/tian"])},
              vitals: %{max_neili: 4000},
              family: %{name: "商家堡"}
            )
          ),
          inquiry_event(config)
        )

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "已经会了吗"
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
        npc_id: Keyword.get(opts, :npc_id, "signature:shang_ming"),
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
    vitals = struct(Vitals.new(), Keyword.get(opts, :vitals, %{}))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: vitals,
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

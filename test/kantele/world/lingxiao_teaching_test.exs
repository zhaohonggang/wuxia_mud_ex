defmodule Kantele.World.LingxiaoTeachingTest do
  @moduledoc """
  #1022 凌霄城（雪山剑派）教学门控定向测试。

  数据来源：LPC `kungfu/class/lingxiao/{lingxiao.h,baiwanjian.c,baizizai.c,
  gengwanzhong.c,huawanzi.c,huyanwanshan.c,kewanjun.c,luwantong.c,shipopo.c,
  shiqing.c,wangwanren.c,wenwanfu.c,zhangwanfeng.c}` 与 `d/lingxiao/dadian.c`。
  重点锁定：

    1. `lingxiao.h::permit_recruit` 无条件 `return 0` → 12/12 `deny_all = true`
       + 逐字 `deny_msg`（含石清：LPC 无 `attempt_apprentice`，ex 需显式关掉）；
    2. 11 个 NPC + 石清的战斗闲聊载荷（`chat_chance_combat` / `chat_msg_combat`）；
    3. 白自在「三连环」与「神倒鬼跌三连环」同形 `sect_master_grant`
       （`lingxiao-quan/san`）；
    4. 陆万通 `meta.guarder`（family + 两句拒绝台词）与 `coagents`（白万剑）；
    5. 石清 `teach.recognize` 四门顺序（师父名 → 侠义 → 技能白名单 → 技能上限）；
    6. `lingxiao:dadian` 守卫方向规则：east/west/north 拦，up/south 放行。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, alias_key) do
    Enum.find(world.characters, fn c ->
      Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
    end)
  end

  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  # ---------- 1. 收徒门控（lingxiao.h permit_recruit 恒拒）----------

  describe "apprentice 门控 —— lingxiao.h permit_recruit 恒 0" do
    @deny "对不起，我雪山剑派不对外收徒。"

    @keys [
      "baiwanjian",
      "baizizai",
      "gengwanzhong",
      "huawanzi",
      "huyanwanshan",
      "kewanjun",
      "luwantong",
      "shipopo",
      "shiqing",
      "wangwanren",
      "wenwanfu",
      "zhangwanfeng"
    ]

    test "12/12 NPC 都是 deny_all + 逐字 deny_msg", %{world: world} do
      assert length(@keys) == 12

      for key <- @keys do
        app = npc(world, "lingxiao_#{key}").meta.apprentice

        assert app, "lingxiao_#{key} 缺少 apprentice 段"
        assert app.deny_all == true, "lingxiao_#{key} deny_all"
        refute app.permit_recruit == true, "lingxiao_#{key} 不应可收徒"

        if key == "shiqing" do
          # 石清在 LPC 里没有 attempt_apprentice（连拜师命令都不会有回应），
          # 文案不必与 lingxiao.h 那句相同，只要求存在且可回绝。
          assert is_binary(app.deny_msg) and byte_size(app.deny_msg) > 0
        else
          assert app.deny_msg == @deny, "lingxiao_#{key} deny_msg 逐字"
        end
      end
    end

    test "石清无 attempt_apprentice → 也不该能收徒", %{world: world} do
      # LPC shiqing.c 没有 attempt_apprentice；ex NpcFamilyEvent.apprentice 只看
      # teach.family，缺 apprentice 段反而应允收徒，所以显式 deny_all 关掉。
      app = npc(world, "lingxiao_shiqing").meta.apprentice

      assert app.deny_all == true
      assert is_binary(app.deny_msg) and byte_size(app.deny_msg) > 0
    end

    test "12 个 NPC 的 teach.family 仍是凌霄城（否认门只影响拜师，不影响授艺）", %{world: world} do
      for key <- @keys do
        assert npc(world, "lingxiao_#{key}").meta.teach.family == "凌霄城",
               "lingxiao_#{key} teach.family"
      end
    end
  end

  # ---------- 2. 战斗闲聊载荷 ----------

  describe "chat_msg_combat 载荷逐字保留" do
    @payloads %{
      "baiwanjian" => ["sword.hui", "sword.chu", "cuff.jue", "strike.piao", "recover", "powerup"],
      "baizizai" => ["sword.hui", "sword.chu", "sword.feng", "cuff.san", "recover", "powerup"],
      "gengwanzhong" => ["sword.leng", "cuff.jue", "strike.piao", "recover", "powerup"],
      "huawanzi" => ["sword.leng", "cuff.jue", "strike.piao", "recover", "powerup"],
      "huyanwanshan" => ["sword.chong", "cuff.jue", "strike.piao", "recover", "powerup"],
      "kewanjun" => ["sword.chong", "cuff.jue", "strike.piao", "recover", "powerup"],
      "luwantong" => ["sword.chong", "cuff.jue", "strike.piao", "recover", "powerup"],
      "shipopo" => ["blade.chi", "cuff.jue", "strike.piao", "recover", "powerup"],
      "shiqing" => ["sword.zhuo", "sword.qing", "recover"],
      "wangwanren" => ["sword.leng", "cuff.jue", "strike.piao", "recover", "powerup"],
      "wenwanfu" => ["sword.chong", "cuff.jue", "strike.piao", "recover", "powerup"],
      "zhangwanfeng" => ["sword.chong", "cuff.jue", "strike.piao", "recover", "powerup"]
    }

    test "11 个 NPC + 石清的载荷与 LPC 逐条一致", %{world: world} do
      assert map_size(@payloads) == 12

      for {key, payload} <- @payloads do
        ob = npc(world, "lingxiao_#{key}")

        assert ob.meta.chat_msg_combat == payload, "lingxiao_#{key} chat_msg_combat"
      end
    end

    test "chat_chance_combat：石清 100，其余 120", %{world: world} do
      for {key, _payload} <- @payloads do
        ob = npc(world, "lingxiao_#{key}")
        expected = if key == "shiqing", do: 100, else: 120
        assert ob.meta.chat_chance_combat == expected, "lingxiao_#{key} chat_chance_combat"
      end
    end
  end

  # ---------- 3. 白自在 三连环 ----------

  describe "白自在「三连环」双键同形 sect_master_grant" do
    test "三连环 与 神倒鬼跌三连环 都指向 lingxiao-quan/san", %{world: world} do
      bzz = npc(world, "lingxiao_baizizai")

      for key <- ["三连环", "神倒鬼跌三连环"] do
        cfg = inquiry(bzz, key)

        assert cfg["kind"] == "sect_master_grant", "#{key} kind"
        assert cfg["perform_id"] == "lingxiao-quan/san", "#{key} perform_id"
        assert cfg["skill"] == "lingxiao-quan"
        assert cfg["gate_order"] == "lpc_kunlun"
        assert cfg["family"] == "凌霄城"
        assert cfg["min_gongxian"] == 1500
        assert cfg["cost_gongxian"] == 1500
        assert cfg["learned"] == "你学会了「神倒鬼跌三连环」。\\n"
      end
    end

    test "lpc_kunlun 门序：已会 → 同门 → 技能 → 贡献 → 内功 → 等级", %{world: world} do
      bzz = npc(world, "lingxiao_baizizai")
      cfg = inquiry(bzz, "三连环")
      npc_stats = %{family: "凌霄城"}

      base = [gongxian: 2000, shen: 20_000, skills: %{"lingxiao-quan" => 200, "force" => 300}]

      known = grant_player(base ++ [performs: MapSet.new(["lingxiao-quan/san"])])

      assert {:error, "自己下去练，别老跟我纠缠不休！\n"} = SectMaster.inquiry_grant(known, npc_stats, cfg)

      outsider =
        grant_player(
          family: "武当派",
          gongxian: 2000,
          shen: 20_000,
          skills: %{"lingxiao-quan" => 200, "force" => 300}
        )

      assert {:error, "你是哪里来的？快给我快快滚开！\n"} = SectMaster.inquiry_grant(outsider, npc_stats, cfg)

      no_skill =
        grant_player(
          gongxian: 2000,
          shen: 20_000,
          skills: %{"lingxiao-quan" => 0, "force" => 300}
        )

      assert {:error, "你连凌霄拳法都没学，还谈什么绝招可言？\n"} =
               SectMaster.inquiry_grant(no_skill, npc_stats, cfg)

      low_gongxian =
        grant_player(
          gongxian: 1499,
          shen: 20_000,
          skills: %{"lingxiao-quan" => 200, "force" => 300}
        )

      assert {:error, "哼，你在本派中无所作为，这一招我暂时还不能传你。\n"} =
               SectMaster.inquiry_grant(low_gongxian, npc_stats, cfg)

      low_force =
        grant_player(
          gongxian: 2000,
          shen: 20_000,
          skills: %{"lingxiao-quan" => 200, "force" => 249}
        )

      assert {:error, "你的内功修行实在太差，下去练练再来！\n"} =
               SectMaster.inquiry_grant(low_force, npc_stats, cfg)

      low_skill =
        grant_player(
          gongxian: 2000,
          shen: 20_000,
          skills: %{"lingxiao-quan" => 179, "force" => 300}
        )

      assert {:error, "亏你凌霄拳法练成这样，也好意思来找我。\n"} =
               SectMaster.inquiry_grant(low_skill, npc_stats, cfg)

      good = grant_player(base)
      assert {:ok, "lingxiao-quan/san", 1500} = SectMaster.inquiry_grant(good, npc_stats, cfg)
    end
  end

  # ---------- 4. 陆万通 guarder + coagents ----------

  describe "陆万通 guarder / coagents" do
    test "meta.guarder family=凌霄城 + 两句逐字拒绝台词", %{world: world} do
      guarder = npc(world, "lingxiao_luwantong").meta.guarder

      assert guarder.family == "凌霄城"

      assert guarder.msgs.refuse_other ==
               "{npc}对{name}冷喝道：你给我站住！我们凌宵宫岂是由得外人随便走动地方？"

      assert guarder.msgs.refuse_carry ==
               "{npc}对{name}喝道：你背上背的是什么人？给我放下来！"

      refute Map.values(guarder.msgs) |> Enum.any?(&String.contains?(&1, "$N"))
      refute Map.values(guarder.msgs) |> Enum.any?(&String.contains?(&1, "$n"))
    end

    test "coagents 指向白万剑 / lingxiao:qihan", %{world: world} do
      coagents = npc(world, "lingxiao_luwantong").meta.coagents

      assert is_list(coagents)
      assert length(coagents) == 1

      [co] = coagents
      assert co["id"] == "bai wanjian"
      assert co["startroom"] == "lingxiao:qihan"
    end
  end

  # ---------- 5. 闻万夫 rescue ----------

  describe "闻万夫 meta.rescue（#1027 数据侧）" do
    test "rescue 配置：3 个弟子 + kill 触发 + 助战台词", %{world: world} do
      rescue_cfg = npc(world, "lingxiao_wenwanfu").meta.rescue

      assert is_map(rescue_cfg)
      assert rescue_cfg.npc_ids == ["lingxiao dizi", "lingxiao dizi", "lingxiao dizi"]
      assert rescue_cfg.types == ["kill"]

      assert rescue_cfg.vision ==
               "闻万夫大怒，喝道：居然欺到我们凌宵城头上来了，大家并肩子上！"
    end

    test "lingxiao:gate 同房间有凌霄弟子（rescue 有可召唤对象）", %{world: world} do
      occupants = Enum.filter(world.characters, &(&1.room_id == "lingxiao:gate"))

      names = Enum.map(occupants, & &1.name)

      # LPC wenwanfu.c 的 present("lingxiao dizi") 靠别名解析；这里锁的是
      # 房间里确实有 3 个可被 lingxiao dizi 命中的弟子 + 闻万夫本人。
      dizi =
        Enum.count(occupants, fn c ->
          aliases = [c.name | c.meta.aliases || []] |> Enum.map(&String.downcase/1)
          "lingxiao dizi" in aliases
        end)

      assert dizi >= 3, "lingxiao:gate 应有至少 3 个可被 'lingxiao dizi' 命中的弟子，实际 #{dizi}"
      assert "闻万夫" in names, "lingxiao:gate 应放置闻万夫"
    end
  end

  # ---------- 6. 石清 recognize 四门 ----------

  describe "石清 teach.recognize 四门（LPC shiqing.c::recognize_apprentice）" do
    # 石清没有 apprentice 段，teachable? 直读 teach.recognize。
    defp shiqing_student(overrides \\ %{}) do
      overrides = Map.new(overrides)

      stats =
        Map.merge(
          %{shen: 20_000, combat_exp: 0, skills: %{}},
          Map.get(overrides, :stats, %{})
        )

      %{
        meta: %{
          family: Map.get(overrides, :family, %{name: "凌霄城", master_name: "白自在"}),
          stats: stats,
          marks: Map.get(overrides, :marks, %{})
        }
      }
    end

    test "第一门：非白自在门下 → 素无渊源", %{world: world} do
      sq = npc(world, "lingxiao_shiqing")

      student = shiqing_student(family: %{name: "凌霄城", master_name: "白万剑"})

      assert {:error, "石某与阁下素无渊源，不知阁下这话从何而来？\n"} =
               SectMaster.teachable?(sq, student, "shangqing-jian")

      no_family = shiqing_student(family: %{})
      assert {:error, "石某与阁下素无渊源，不知阁下这话从何而来？\n"} = SectMaster.teachable?(sq, no_family, "sword")
    end

    test "第二门：侠义 < 10000 → 侠义不足", %{world: world} do
      sq = npc(world, "lingxiao_shiqing")
      student = shiqing_student(stats: %{shen: 9_999})

      assert {:error, "学武之人，自应以德义为先。你侠义正事做得不够，这招我不能传你。\n"} =
               SectMaster.teachable?(sq, student, "shangqing-jian")
    end

    test "第三门：非上清剑法/剑法 → 另投名师", %{world: world} do
      sq = npc(world, "lingxiao_shiqing")

      for skill <- ["force", "yunhe-jian", "piaoxu-zhang"] do
        assert {:error, "阁下的武功，在下实在无从指点，请另投名师吧。\n"} =
                 SectMaster.teachable?(sq, shiqing_student(), skill)
      end
    end

    test "第四门：sword > 179 → 已不弱于在下", %{world: world} do
      sq = npc(world, "lingxiao_shiqing")

      over = shiqing_student(stats: %{skills: %{"sword" => 180}})
      assert {:error, "这一门功夫你已不弱于在下，没什么可教的了。\n"} = SectMaster.teachable?(sq, over, "sword")

      # 179 是放行边界：用石清**不教**的 force（白名单外）会把门推到第三门，
      # 所以改用「sword=179 但 skill=force」验证第四门 `> 179` 不命中。
      # 注意 force 不在 allowed_skills，会先撞第三门；故直接锁定 180/179 的分界：
      at_179 = shiqing_student(stats: %{skills: %{"sword" => 179}})

      # 179 不撞第四门（> 179 才拦）→ 会落到「同门派非嫡传」门，说明第四门已放行
      assert {:error, "你已入别派，老夫不便传授。\n"} = SectMaster.teachable?(sq, at_179, "sword")

      at_180 = shiqing_student(stats: %{skills: %{"sword" => 180}})
      assert {:error, "这一门功夫你已不弱于在下，没什么可教的了。\n"} = SectMaster.teachable?(sq, at_180, "sword")
    end

    test "recognize 放行且为非同门（散人）→ 落到「师父不高于学生」门", %{world: world} do
      # 非凌霄城 + 白自在门下（LPC 第一门只查 master_name）+ 侠义达标 + sword 100
      # → recognize 四门全过；非同派 → 不撞「你已入别派」。
      # #1040 后 NPC 顶层 skills 已进 stats.skills：石清 sword 真实等级高于学生，
      # 常规「师父不高于学生」门不再命中 → recognize 四门全过后应落到 :ok。
      # 这锁的是「recognize 放行后交给常规链」，而非旧的空技能恒拒假设。
      sq = npc(world, "lingxiao_shiqing")

      outsider =
        shiqing_student(
          family: %{name: "散人", master_name: "白自在"},
          stats: %{shen: 20_000, skills: %{"sword" => 100}}
        )

      assert SectMaster.teachable?(sq, outsider, "sword") == :ok

      # 上清剑法同理：shangqing-jian=200 > 179 → 先撞 recognize 第四门（maxed_deny「在下」）
      outsider2 =
        shiqing_student(
          family: %{name: "散人", master_name: "白自在"},
          stats: %{shen: 20_000, skills: %{"shangqing-jian" => 200}}
        )

      assert {:error, "这一门功夫你已不弱于在下，没什么可教的了。\n"} =
               SectMaster.teachable?(sq, outsider2, "shangqing-jian")
    end

    test "recognize 通过且为同门派非嫡传 → 回落「你已入别派」门", %{world: world} do
      # recognize 四门放行后（凌霄城/白自在 + 侠义达标 + sword 100），学生同门派但
      # 非嫡传 → 撞 Master.prevent_learn?「你已入别派」。
      # 这条锁的是「recognize 通过不会吞掉后续常规门」的顺序语义。
      sq = npc(world, "lingxiao_shiqing")

      student =
        shiqing_student(
          family: %{name: "凌霄城", master_name: "白自在"},
          stats: %{shen: 50_000, skills: %{"sword" => 100}}
        )

      assert {:error, "你已入别派，老夫不便传授。\n"} = SectMaster.teachable?(sq, student, "sword")
    end
  end

  # ---------- 7. 凌霄殿守卫方向 ----------

  describe "lingxiao:dadian 守卫方向（LPC dadian.c::valid_leave）" do
    alias Kalevala.Event
    alias Kalevala.Event.Movement
    alias Kalevala.World.Room.Context

    @handler Kalevala.World.Room.Callbacks.Kantele.World.Room

    setup do
      world = Loader.load()

      Enum.each(world.zones, fn
        %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
        _ -> :skip
      end)

      room = Enum.find(world.rooms, &(&1.id == "lingxiao:dadian"))
      occupants = Enum.filter(world.characters, &(&1.room_id == "lingxiao:dadian"))

      %{room: room, occupants: occupants}
    end

    defp room_exit(room, dir) do
      Enum.find(room.exits, &(&1.exit_name == dir))
    end

    defp mover(family_name) do
      family = if family_name, do: %{name: family_name}, else: nil
      %{pid: self(), name: "测试玩家", meta: %{family: family}}
    end

    defp move(room, characters, player, dir) do
      exit = room_exit(room, dir)
      assert exit, "dadian 没有方向 #{dir}"

      event = %Event{
        topic: Movement.Request,
        from_pid: self(),
        data: %Movement.Request{character: player, exit_name: dir}
      }

      context = %Context{
        data: room,
        characters: characters,
        item_instances: [],
        assigns: %{},
        events: [],
        output: []
      }

      @handler.movement_request(room, context, event, exit)
    end

    test "behavior_config 只守 east/west/north", %{room: room} do
      assert room.behavior == "guarded_exit"
      assert room.behavior_config.guard_directions == ["east", "west", "north"]
    end

    test "无门派玩家 east/west/north 被陆万通拦下（占位由 MoveView 渲染）", %{
      room: room,
      occupants: occupants
    } do
      for dir <- ["east", "west", "north"] do
        assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), dir)

        # 房间侧原样带回 LPC 文案（含 {npc}/{name}），玩家侧 MoveView 才替换
        assert msg =~ "我们凌宵宫岂是由得外人随便走动地方？",
               "#{dir} 的拒绝语应出自陆万通的 refuse_other，实际：#{msg}"

        rendered = Kantele.Character.MoveView.render("fail", %{reason: {:guarder_denied, msg}})
        refute rendered =~ "{npc}"
        refute rendered =~ "{name}"
      end
    end

    test "up（通 bar）与 south（通 meiroad1）放行", %{room: room, occupants: occupants} do
      for dir <- ["up", "south"] do
        assert {:proceed, _event, _exit} = move(room, occupants, mover(nil), dir),
               "#{dir} 不设卡，应放行"
      end
    end

    test "凌霄城弟子三向放行", %{room: room, occupants: occupants} do
      for dir <- ["east", "west", "north"] do
        assert {:proceed, _event, _exit} = move(room, occupants, mover("凌霄城"), dir),
               "#{dir} 对本门弟子应放行"
      end
    end

    test "守卫不在场（up/down 房间无陆万通）时放行", %{room: room} do
      # LPC dadian.c：present("lu wantong") 为假 → ::valid_leave 放行
      assert {:proceed, _event, _exit} = move(room, [], mover(nil), "east")
    end
  end

  # 授艺玩家：`Stats` 缺 :max_neili 字段，显式 Map.put。
  defp grant_player(overrides) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, "凌霄城")
    |> Map.put(:max_neili, 6000)
    |> Map.merge(Map.new(overrides))
  end
end

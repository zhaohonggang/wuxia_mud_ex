defmodule Kantele.World.WuduTeachingTest do
  @moduledoc """
  #973 五毒教教学门控定向测试。
  数据来源：LPC `kungfu/class/wudu/{wudu.h,hehongyao.c,qiyunao.c,hetieshou.c,daoshi.c,jiaotou.c,cenqisi.c,panxiuda.c}`。
  重点锁定：
    1. 收徒 `gate_order = "lpc_wudu"` 的两档负侠义阶梯 shen_ladder（-1000/-8000/-15000/-50000
       逐师父）+ reject_master_name（何铁手旧徒）+ min_exp + min_skills。
    2. 齐云敖三绝招（腾蛇诀/毒蟾掌/夺命连环）与何铁手五绝招（盘鹰诀/搏虎诀/锁龙诀/金钩夺魄/无影针）
       的 `lpc_wudu` 门序：已会 → 同门 → 杀气(负上界) → 贡献 → 等级链。
    3. give_item 武器（金蜈钩/软红蛛索/含沙射影）与毒经（中篇/下篇）的家族/master/杀气/技能门槛。
    4. 游方道人传送服务、沙千里 coagent/guarder、何红药 coagent/guarder/战斗闲聊。

  LPC→ex 已知偏差（已登记 GAP §5，非本测试覆盖项）：
    ask_skill1/2/4/5 LPC 为「贡献在杀气前」，lpc_wudu 为「杀气在贡献前」——
    两门槛都触发，仅多门槛同时失败时的拒绝文案先后不同。
    千蛛万毒手 can_learn 标记、武器/毒经持有者状态机（base_name 收回/他人持有）未落地。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name), do: Enum.find(world.characters, fn c -> c.name == name end)
  defp hetieshou(world), do: npc(world, "何铁手")
  defp hehongyao(world), do: npc(world, "何红药")
  defp qiyunao(world), do: npc(world, "齐云敖")
  defp daoshi(world), do: npc(world, "游方道人")
  defp jiaotou(world), do: npc(world, "沙千里")
  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  # inquiry_grant 入参：%Stats{} + :family / :max_neili（宿主补的非 %Stats{} 字段）。
  defp disciple(overrides \\ %{}) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, "五毒教")
    |> Map.put(:max_neili, 0)
    |> Map.merge(Map.new(overrides))
  end

  # recruit_gate? 的 student：meta.family(map) / meta.env / meta.stats。
  defp recruit_student(overrides \\ %{}) do
    overrides = Map.new(overrides)

    stats =
      Map.merge(
        %{
          shen: -100_000,
          combat_exp: 700_000,
          skills: %{"wudu-xinfa" => 150, "wudu-qishu" => 150}
        },
        Map.get(overrides, :stats, %{})
      )

    %{
      meta: %{
        family: Map.get(overrides, :family, %{name: "五毒教", master_name: nil}),
        env: Map.get(overrides, :env, %{}),
        stats: stats
      }
    }
  end

  # ---------- 1. UCL 数据回填 ----------

  describe "UCL 数据回填（Loader 归一后）" do
    test "何铁手五绝招：lpc_wudu 门控字段与 LPC ask_skill 一致", %{world: world} do
      npc = hetieshou(world)
      assert npc, "何铁手应随世界加载"

      expected = [
        {"盘鹰诀", "ruanhong-zhusuo/pan", 300, -30_000, %{"ruanhong-zhusuo" => 130}},
        {"搏虎诀", "ruanhong-zhusuo/bohu", 1300, -50_000, %{"ruanhong-zhusuo" => 160}},
        {"锁龙诀", "ruanhong-zhusuo/suo", 1500, -80_000, %{"ruanhong-zhusuo" => 160}},
        {"金钩夺魄", "jinwu-goufa/duo", 1300, -80_000, %{"jinwu-goufa" => 160}},
        {"无影针", "hansha-sheying/zhen", 300, -80_000, %{"hansha-sheying" => 120}}
      ]

      for {key, perform_id, cost, max_shen, min_levels} <- expected do
        cfg = inquiry(npc, key)
        assert cfg["gate_order"] == "lpc_wudu", "#{key} 必须走 lpc_wudu 门序"
        assert cfg["perform_id"] == perform_id
        assert cfg["cost_gongxian"] == cost, "#{key} 贡献消耗"
        assert cfg["max_shen"] == max_shen, "#{key} 负侠义上界"
        assert cfg["min_levels"] == min_levels, "#{key} 等级门槛"
        assert cfg["shen_deny"] =~ "心慈手软", "#{key} 杀气拒绝文案"
        assert cfg["gongxian_deny"] =~ "贡献", "#{key} 贡献拒绝文案"
      end
    end

    test "齐云敖三绝招：lpc_wudu 门控字段", %{world: world} do
      npc = qiyunao(world)
      assert npc, "齐云敖应随世界加载"

      teng = inquiry(npc, "腾蛇诀")
      assert teng["gate_order"] == "lpc_wudu"
      assert teng["perform_id"] == "xiewei-bian/teng"
      assert teng["max_shen"] == -20_000
      assert teng["min_gongxian"] == 100
      assert teng["cost_gongxian"] == 100
      assert teng["min_levels"] == %{"xiewei-bian" => 100}

      chan = inquiry(npc, "毒蟾掌")
      assert chan["gate_order"] == "lpc_wudu"
      assert chan["perform_id"] == "tianchan-zhang/chan"
      assert chan["max_shen"] == -35_000
      assert chan["min_gongxian"] == 200
      assert chan["level_order"] == ["force", "tianchan-zhang"]
      assert chan["min_levels"] == %{"force" => 150, "tianchan-zhang" => 120}

      lian = inquiry(npc, "夺命连环")
      assert lian["gate_order"] == "lpc_wudu"
      assert lian["perform_id"] == "wusheng-zhao/lian"
      assert lian["max_shen"] == -40_000
      assert lian["min_gongxian"] == 300
      assert lian["level_order"] == ["force", "wusheng-zhao"]
    end

    test "give_item 武器/毒经：家族/master/杀气/技能门槛字段", %{world: world} do
      h = hetieshou(world)

      gou = inquiry(h, "金蜈钩")
      assert gou["kind"] == "give_item"
      assert gou["item"] == "clone_lib:jinwugou"
      assert gou["master_id"] in [true, "true"]
      assert gou["max_shen"] == -35_000
      assert gou["min_skill_levels"] == %{"jinwu_goufa" => 120}
      assert gou["master_deny"] =~ "只有我的弟子"

      suo = inquiry(h, "软红蛛索")
      assert suo["kind"] == "give_item"
      assert suo["item"] == "clone_lib:zhusuo"
      assert suo["master_id"] in [true, "true"]
      assert suo["max_shen"] == -35_000
      assert suo["min_skill_levels"] == %{"ruanhong_zhusuo" => 150}

      # 含沙射影 LPC 无 master_id 门（hetieshou.c ask_she）
      she = inquiry(h, "含沙射影")
      assert she["kind"] == "give_item"
      assert she["item"] == "clone_lib:sheying"
      assert she["max_shen"] == -10_000
      assert she["min_skill_levels"] == %{"hansha_sheying" => 50}

      # 毒经下篇（wudu:dujing3 新建物品）
      xp = inquiry(h, "下篇")
      assert xp["kind"] == "give_item"
      assert xp["item"] == "wudu:dujing3"
      assert xp["max_shen"] == -30_000
      assert xp["min_combat_exp"] == 150_000
      assert xp["max_skill_levels"] == %{"wudu-qishu" => 149}

      # 千蛛万毒手为显式 GAP 占位（can_learn 标记），非误导性 give_item
      gap = inquiry(h, "千蛛万毒手")
      assert gap["kind"] == "unimplemented_gap"

      # 齐云敖毒经中篇
      zj = inquiry(qiyunao(world), "毒经中篇")
      assert zj["kind"] == "give_item"
      assert zj["item"] == "wudu:dujing2"
      assert zj["max_shen"] == -10_000
      assert zj["min_combat_exp"] == 100_000
    end

    test "何红药/齐云敖/何铁手收徒门：shen_ladder 两档负侠义阶梯", %{world: world} do
      hong = hehongyao(world)
      qi = qiyunao(world)
      tie = hetieshou(world)

      for {npc, ladder} <- [
            {hong, [%{max: -1000}, %{max: -8000}]},
            {qi, [%{max: -1000}, %{max: -15_000}]},
            {tie, [%{max: -1000}, %{max: -50_000}]}
          ] do
        app = npc.meta.apprentice
        assert app.gate_order == "lpc_wudu"
        assert app.family == "五毒教"
        assert app.permit_recruit == true
        assert app.reject_master_name == "何铁手"
        assert app.reject_master_name_deny =~ "贱人"
        assert app.betray_sect_deny == "你既然已经离教，就别再回来！"
        assert app.other_family_deny =~ "卧底"

        got_maxes = Enum.map(app.shen_ladder, & &1.max)
        want_maxes = Enum.map(ladder, & &1.max)
        assert got_maxes == want_maxes, "#{npc.name} shen_ladder 两档上界"
        assert length(app.shen_ladder) == 2, "#{npc.name} 应有 2 档 shen_ladder"
      end

      # 护法（cenqisi）单档 + 不同文案
      cen = npc(world, "岑其斯")
      app = cen.meta.apprentice
      assert app.gate_order == "lpc_wudu"
      assert [%{max: -5000}] == Enum.map(app.shen_ladder, &%{max: &1.max})
      assert hd(app.shen_ladder).deny == "做我五毒教弟子必须心狠手辣。"

      # 游方道人传送 + 沙千里 coagent
      d = daoshi(world)
      assert inquiry(d, "五毒教")["kind"] == "teleport_service"
      assert inquiry(d, "五毒教")["target_room"] == "wudu:damen"
      assert inquiry(d, "五毒教")["family_deny"] =~ "罗里八嗦"

      j = jiaotou(world)
      assert j.meta.coagents == [%{"startroom" => "/d/wudu/dating", "id" => "qi yunao"}]
      assert j.meta.guarder.family == "五毒教"
      assert j.meta.guarder.msgs.refuse_other =~ "{npc}"
      assert j.meta.guarder.msgs.refuse_carry =~ "{name}"
    end
  end

  # ---------- 2. 收徒门 recruit_gate? lpc_wudu ----------

  describe "recruit_gate?/3 lpc_wudu 收徒门" do
    test "何红药：叛门/判师/他派/何铁手旧徒 → shen_ladder → 经验 → 技能", %{world: world} do
      app = hehongyao(world).meta.apprentice

      # 判师之徒（betrayed_before：env.betrayer.times > 0）
      betrayed = recruit_student(env: %{betrayer: %{times: 1}})
      assert {:error, "判师之徒，哼！小心我把你千刀万剐！\n"} = SectMaster.recruit_gate?(nil, betrayed, app)

      # 他派（other_family）
      outsider = recruit_student(family: %{name: "华山派", master_name: "岳不群"})
      assert {:error, "你不是已经有了师傅么，还来干什么？做卧底么？\n"} = SectMaster.recruit_gate?(nil, outsider, app)

      # 何铁手旧徒（reject_master_name）
      he_student = recruit_student(family: %{name: "五毒教", master_name: "何铁手"})
      assert {:error, "既然你已经跟随了那个贱人，却又来找我作甚？\n"} = SectMaster.recruit_gate?(nil, he_student, app)

      # shen_ladder 第一档：shen > -1000 → 卧底文案
      spy = recruit_student(stats: %{shen: -999})
      assert {:error, "我越看你越象六扇门派来的卧底。\n"} = SectMaster.recruit_gate?(nil, spy, app)

      # shen_ladder 第二档：-1000 < shen <= -1000 → 心慈手软
      soft = recruit_student(stats: %{shen: -1001})
      assert {:error, "你心慈手软，我是不会收你的！\n"} = SectMaster.recruit_gate?(nil, soft, app)

      # 经验不足
      low_exp = recruit_student(stats: %{shen: -80_000, combat_exp: 59_999})
      assert {:error, "你还是先去增长点经验吧。\n"} = SectMaster.recruit_gate?(nil, low_exp, app)

      # 技能不足（wudu-xinfa 缺）
      weak_skill =
        recruit_student(
          stats: %{shen: -80_000, combat_exp: 100_000, skills: %{"wudu-qishu" => 50}}
        )

      assert {:error, "你的五毒心法还学的不够啊。\n"} = SectMaster.recruit_gate?(nil, weak_skill, app)

      # 全达标 → ok
      ok = recruit_student()
      assert {:ok, "不错，不错。\n"} = SectMaster.recruit_gate?(nil, ok, app)
    end

    test "何铁手：第二档 -50000 上界更高（更邪恶才收）", %{world: world} do
      app = hetieshou(world).meta.apprentice

      # 杀气 -10000（足够狠但对何铁手仍不够）→ 第二档
      moderate = recruit_student(stats: %{shen: -10_000, combat_exp: 400_000})
      assert {:error, "像你这样心慈手软的人是干不成大事的！\n"} = SectMaster.recruit_gate?(nil, moderate, app)

      # -50001 → 过两档，经验/技能达标 → ok
      evil = recruit_student(stats: %{shen: -50_001, combat_exp: 400_000})
      assert {:ok, "好吧，既然如此本姑娘就收下你这个徒弟。\n"} = SectMaster.recruit_gate?(nil, evil, app)
    end
  end

  # ---------- 3. inquiry_grant/3 lpc_wudu 绝招门序 ----------

  describe "inquiry_grant/3 lpc_wudu 绝招门序" do
    test "齐云敖腾蛇诀：已会 / 非同门 / 杀气 / 贡献 / 等级按 LPC 顺序", %{world: world} do
      cfg = inquiry(qiyunao(world), "腾蛇诀")
      npc_stats = %{family: "五毒教"}

      assert {:error, "你不是已经会了吗？\n"} =
               SectMaster.inquiry_grant(
                 disciple(performs: MapSet.new(["xiewei-bian/teng"])),
                 npc_stats,
                 cfg
               )

      assert {:error, "不是我们五毒教的人，何出此言？\n"} =
               SectMaster.inquiry_grant(disciple(family: "华山派"), npc_stats, cfg)

      # shen 上界（负）：shen > -20000 → 拒
      assert {:error, "像你这样心慈手软，就算学了这招也干不了大事！\n"} =
               SectMaster.inquiry_grant(
                 disciple(shen: -19_999, gongxian: 200, skills: %{"xiewei-bian" => 100}),
                 npc_stats,
                 cfg
               )

      # 贡献不足
      assert {:error, "你在教中所作的贡献还不够，这招我不忙传你。\n"} =
               SectMaster.inquiry_grant(
                 disciple(shen: -30_000, gongxian: 99, skills: %{"xiewei-bian" => 100}),
                 npc_stats,
                 cfg
               )

      # 等级不足
      assert {:error, "你的蝎尾鞭还不到家，要多练练！"} =
               SectMaster.inquiry_grant(
                 disciple(shen: -30_000, gongxian: 100, skills: %{"xiewei-bian" => 99}),
                 npc_stats,
                 cfg
               )

      # 全达标 → ok
      assert {:ok, "xiewei-bian/teng", 100} =
               SectMaster.inquiry_grant(
                 disciple(shen: -20_000, gongxian: 100, skills: %{"xiewei-bian" => 100}),
                 npc_stats,
                 cfg
               )
    end

    test "齐云敖毒蟾掌：level_order 内功先于掌法", %{world: world} do
      cfg = inquiry(qiyunao(world), "毒蟾掌")
      npc_stats = %{family: "五毒教"}

      # force 150 与 tianchan-zhang 120 双门槛；force 不足先报内功
      assert {:error, "你的内功火候不够，练不成这招！\n"} =
               SectMaster.inquiry_grant(
                 disciple(
                   shen: -40_000,
                   gongxian: 200,
                   skills: %{"force" => 149, "tianchan-zhang" => 120}
                 ),
                 npc_stats,
                 cfg
               )

      assert {:error, "你的天蟾掌法还不到家，要多练练！\n"} =
               SectMaster.inquiry_grant(
                 disciple(
                   shen: -40_000,
                   gongxian: 200,
                   skills: %{"force" => 150, "tianchan-zhang" => 119}
                 ),
                 npc_stats,
                 cfg
               )

      assert {:ok, "tianchan-zhang/chan", 200} =
               SectMaster.inquiry_grant(
                 disciple(
                   shen: -40_000,
                   gongxian: 200,
                   skills: %{"force" => 150, "tianchan-zhang" => 120}
                 ),
                 npc_stats,
                 cfg
               )
    end

    test "何铁手盘鹰诀：lpc_wudu 门序（杀气在贡献前）", %{world: world} do
      cfg = inquiry(hetieshou(world), "盘鹰诀")
      npc_stats = %{family: "五毒教"}

      assert {:ok, "ruanhong-zhusuo/pan", 300} =
               SectMaster.inquiry_grant(
                 disciple(shen: -30_000, gongxian: 300, skills: %{"ruanhong-zhusuo" => 130}),
                 npc_stats,
                 cfg
               )

      # 杀气不足 + 贡献不足：lpc_wudu 先报杀气（LPC ask_skill1 为贡献先，属 GAP）
      assert {:error, "心慈手软的人永远成不了大器，这招你不学也罢！\n"} =
               SectMaster.inquiry_grant(
                 disciple(shen: -29_999, gongxian: 100, skills: %{"ruanhong-zhusuo" => 130}),
                 npc_stats,
                 cfg
               )
    end

    test "软红蛛索：master 门 + min_skill_levels 键保下划线（give_item 专门路径）", %{world: world} do
      cfg = inquiry(hetieshou(world), "软红蛛索")

      # min_skill_levels 键与 Stats.skills 同形（下划线，give_item 不归一 _→-）
      assert cfg["min_skill_levels"] == %{"ruanhong_zhusuo" => 150}
      assert cfg["master_id"] in [true, "true"]
      assert cfg["master_deny"] == "只有我的弟子才能用软红蛛索，你拿去用只会替我丢脸。"
      assert cfg["family_deny"] == "你不是我们五毒教的，打听它干什么？"
      assert cfg["already"] =~ "软红蛛索现在不是你拿着在用吗？"
    end
  end

  describe "毒经下篇物品（wudu:dujing3）落位" do
    test "dujing3 随世界加载且 skill=wudu-qishu", %{world: world} do
      item = Enum.find(world.items, fn i -> i.id == "wudu:dujing3" or i.name == "「毒经下篇」" end)
      assert item, "毒经下篇应随世界加载"
      assert item.name == "「毒经下篇」"
      assert item.meta.book.skill == "wudu-qishu"
      assert item.meta.book.min_skill == 50
      assert item.meta.book.max_skill == 149
      assert item.meta.book.exp_required == 150_000
    end
  end
end

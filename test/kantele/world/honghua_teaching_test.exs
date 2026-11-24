defmodule Kantele.World.HonghuaTeachingTest do
  @moduledoc """
  #1009-#1012 红花会教学门控定向测试。

  数据来源：LPC `kungfu/class/honghua/{honghua.h,chang1.c,chang2.c,chen.c,jiang.c,lu.c,
  luo.c,shi.c,wen.c,wuchen.c,yang.c,yu.c,zhao.c}` 与 `d/hangzhou/honghua/wuchen.c`。重点锁定：

    1. 9 位 clone_lib 师父 + kaifeng 无尘道长的 `honghua.h` 三条逐字 permit 文案；
    2. 陈家洛 `lpc_honghua_chen` 与余鱼同 `lpc_honghua_yu` 的独立收徒门序；
    3. 16 条 `lpc_honghua` 绝招的已会→同门→技能存在→贡献→侠义→前置→等级链；
    4. 剑盾珠索/芙蓉金针/白龙剑/回龙璧四件物品的师父白名单、双门派与门序配置；
    5. 11 位 clone_lib NPC + 无尘道长的战斗闲聊载荷。

  已知偏差（GAP #1013-#1020，非本测试覆盖项）：物品 owner/is_bad 状态机、陆菲青
  recognize_apprentice、陈家洛 try_to_learn_quan、guarder/coagent 互救、message_vision
  表情与颜色、NPC 通用属性、文泰来 unconcious 死亡覆写、improve_skill 潜力重复调用。
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

  defp wuchen(world) do
    Enum.find(world.characters, fn c ->
      c.meta.zone_id == "kaifeng" and c.name == "无尘道长"
    end)
  end

  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  # 收徒考察者：缺省满足红花会各师父硬门（高侠义/高经验/心法与剑法充足）。
  defp recruit_student(overrides \\ %{}) do
    overrides = Map.new(overrides)

    stats =
      Map.merge(
        %{
          shen: 100_000,
          combat_exp: 500_000,
          skills: %{"honghua-xinfa" => 200, "sword" => 200}
        },
        Map.get(overrides, :stats, %{})
      )

    %{
      meta: %{
        family: Map.get(overrides, :family, %{name: "红花会", master_name: nil}),
        env: Map.merge(%{gender: "男性"}, Map.get(overrides, :env, %{})),
        stats: stats,
        vitals: Map.get(overrides, :vitals, %{max_neili: 6000})
      }
    }
  end

  # 授艺玩家：`Stats` 缺 :max_neili 字段，显式 Map.put（与既有 teaching 测试一致）。
  defp grant_player(overrides) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, "红花会")
    |> Map.put(:max_neili, 6000)
    |> Map.put(:dex, 40)
    |> Map.merge(Map.new(overrides))
  end

  defp apprentice_expectations do
    %{
      "honghua_chang1" => {5000, 0, %{"honghua-xinfa" => 50}, "以后你就跟着老子吧。"},
      "honghua_chang2" => {5000, 0, %{"honghua-xinfa" => 50}, "以后你就跟着老子吧。"},
      "honghua_chen" =>
        {65_000, 400_000, %{"honghua-xinfa" => 100},
         "不错，不错。念在你如此有心，又乃我侠义中人，今日我便收下你。希望阁下日后多行善事，为我红花会发扬壮大。"},
      "honghua_jiang" => {-1000, 0, %{}, "嗯。那我就收下你吧。"},
      "honghua_luo" => {-1000, 0, %{}, "既然这样，我就收下你好了。"},
      "honghua_wen" => {10_000, 150_000, %{"honghua-xinfa" => 60}, "不错，不错，你以后就跟着我吧。"},
      "honghua_yang" => {-1000, 0, %{}, "嗯。那你以后跟着我好了。"},
      "honghua_yu" => {0, 0, %{}, nil},
      "honghua_zhao" => {15_000, 200_000, %{"honghua-xinfa" => 80}, "念在你如此有心，我便收下你好了。"}
    }
  end

  defp grant_expectations do
    [
      {"honghua_chang1", "催魂掌", "heisha-zhang/cui"},
      {"honghua_chen", "缚字诀", "jiandun-zhusuo/fu"},
      {"honghua_chen", "千头万绪", "jiandun-zhusuo/qian"},
      {"honghua_chen", "化蝶", "zhuangzi-wu/hua"},
      {"honghua_chen", "百花错乱", "baihua-cuoquan/luan"},
      {"honghua_chen", "百花错易", "baihua-cuoquan/yi"},
      {"honghua_chen", "战神轰天诀", "baihua-cuoquan/hong"},
      {"honghua_lu", "玄功无极劲", "xuangong-quan/xuan"},
      {"honghua_lu", "三环套月", "rouyun-jian/tao"},
      {"honghua_lu", "金针现影", "furong-jinzhen/xian"},
      {"honghua_luo", "刀影重重", "hanwang-qingdao/ying"},
      {"honghua_wen", "雷霆万钧", "benlei-zhang/lei"},
      {"honghua_zhao", "掌藏龙", "huilong-bifa/cang"},
      {"kaifeng:wuchen", "夺命连环", "lianhuan-mizongtui/lian"},
      {"kaifeng:wuchen", "追魂夺命", "zhuihun-jian/zhui"},
      {"kaifeng:wuchen", "诛天刹神", "zhuihun-jian/zhu"}
    ]
  end

  defp ob(world, "kaifeng:wuchen"), do: wuchen(world)
  defp ob(world, alias_key), do: npc(world, alias_key)

  # ---------- 1. 收徒配置 ----------

  describe "apprentice 逐字文案与硬门配置" do
    test "9 位 clone_lib permit 师父 + 无尘道长：honghua.h 三句逐字覆写", %{world: world} do
      keys = Map.keys(apprentice_expectations()) ++ ["kaifeng:wuchen"]

      for key <- keys do
        app = ob(world, key).meta.apprentice

        assert app.family == "红花会"
        assert app.permit_recruit == true
        assert app.deny_all == false
        assert app.betray_sect_deny == "我们红花会四大戒条你还记得吗？亏你还有脸回来！"
        assert app.betray_times_deny == "哼，阁下不忠不信，我们红花会可不会收留。"
        assert app.other_family_deny == "阁下既有了师承，还来我们红花会做什么？"
      end
    end

    test "9 位师父的 shen/exp/skills/accept 逐项对齐 LPC", %{world: world} do
      for {key, {shen, exp, skills, accept}} <- apprentice_expectations() do
        app = npc(world, key).meta.apprentice

        assert app.min_shen == shen, "#{key} min_shen"
        assert app.min_exp == exp, "#{key} min_exp"
        assert app.min_skills == skills, "#{key} min_skills"
        assert app.accept_msg == accept, "#{key} accept_msg"
      end
    end

    test "无尘道长：shen20000 → exp350000 → 红花心法80 → 剑法80 有序门", %{world: world} do
      app = wuchen(world).meta.apprentice

      assert app.min_shen == 20_000
      assert app.min_shen_deny == "你非我侠义中人，我不能收你。"
      assert app.min_exp == 350_000
      assert app.min_exp_deny == "你的江湖经验太浅，就算收了你，恐怕也难有作为。"
      assert app.min_skills == %{"honghua-xinfa" => 80, "sword" => 80}
      assert app.recruit_skill_order == ["honghua-xinfa", "sword"]
      assert app.accept_msg == "既然如此，那你以后就跟着我好了。"
    end

    test "陈家洛/余鱼同独立门序 + 陆菲青/石双英 deny_all 配置", %{world: world} do
      assert npc(world, "honghua_chen").meta.apprentice.gate_order == "lpc_honghua_chen"
      assert npc(world, "honghua_yu").meta.apprentice.gate_order == "lpc_honghua_yu"
      assert npc(world, "honghua_yu").meta.apprentice.deny_msg == "我不收徒，你找其余几位当家的好了。"

      for key <- ["honghua_lu", "honghua_shi"] do
        app = npc(world, key).meta.apprentice
        assert app.deny_all == true
        assert app.permit_recruit == false
        assert is_binary(app.deny_msg) and byte_size(app.deny_msg) > 0
      end

      assert npc(world, "honghua_lu").meta.apprentice.deny_msg ==
               "我不收徒，若要拜师你直接去武当山好了。"

      assert npc(world, "honghua_shi").meta.apprentice.deny_msg ==
               "你不收徒，你找其余当家的吧。"
    end
  end

  # ---------- 2. 收徒门运行 ----------

  describe "recruit_gate?/3 运行门序" do
    test "honghua.h 三问：离派 → 判师 → 他派，逐字拒绝", %{world: world} do
      app = npc(world, "honghua_chang1").meta.apprentice

      assert :ok = SectMaster.recruit_gate?(nil, recruit_student(), app)

      leave = recruit_student(env: %{"detach" => %{"红花会" => true}})

      assert {:error, "我们红花会四大戒条你还记得吗？亏你还有脸回来！\n"} = SectMaster.recruit_gate?(nil, leave, app)

      betray = recruit_student(env: %{"betrayer" => %{"times" => 2}})

      assert {:error, "哼，阁下不忠不信，我们红花会可不会收留。\n"} = SectMaster.recruit_gate?(nil, betray, app)

      other = recruit_student(family: %{name: "武当派", master_name: nil})

      assert {:error, "阁下既有了师承，还来我们红花会做什么？\n"} = SectMaster.recruit_gate?(nil, other, app)
    end

    test "常赫志：shen → 红花心法，逐字拒绝与缺省 :ok", %{world: world} do
      app = npc(world, "honghua_chang1").meta.apprentice

      assert :ok = SectMaster.recruit_gate?(nil, recruit_student(), app)

      assert {:error, "你非我侠义中人，我不能收你。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{shen: 4999}),
                 app
               )

      assert {:error, "你把本门的心法练好了再来。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{skills: %{"honghua-xinfa" => 49}}),
                 app
               )
    end

    test "陈家洛：shen → exp → 红花心法 → max_neili 四门不可颠倒", %{world: world} do
      app = npc(world, "honghua_chen").meta.apprentice
      good = recruit_student(stats: %{shen: 65_000, combat_exp: 400_000})

      assert {:ok, "不错，不错。念在你如此有心，又乃我侠义中人，今日我便收下你。希望阁下日后多行善事，为我红花会发扬壮大。\n"} =
               SectMaster.recruit_gate?(nil, good, app)

      all_low =
        recruit_student(
          stats: %{
            shen: 64_999,
            combat_exp: 0,
            skills: %{"honghua-xinfa" => 1}
          },
          vitals: %{max_neili: 1}
        )

      assert {:error, "我红花会乃为救天下苍生而建，所做的一切无不以侠义为重。阁下在德行方面，似乎还做得不够。\n"} =
               SectMaster.recruit_gate?(nil, all_low, app)

      exp_low =
        recruit_student(
          stats: %{combat_exp: 399_999, skills: %{"honghua-xinfa" => 1}},
          vitals: %{max_neili: 1}
        )

      assert {:error, "你的江湖经验太浅，我就算收了你，恐怕你也难有所作为。\n"} =
               SectMaster.recruit_gate?(nil, exp_low, app)

      skill_low =
        recruit_student(
          stats: %{skills: %{"honghua-xinfa" => 99}},
          vitals: %{max_neili: 1}
        )

      assert {:error, "你本门的内功心法都未练透，如何跟我习高深的武学？\n"} =
               SectMaster.recruit_gate?(nil, skill_low, app)

      neili_low = recruit_student(vitals: %{max_neili: 1999})

      assert {:error, "我的武功全需强大的内功为辅，阁下似乎应该多练练内力。\n"} =
               SectMaster.recruit_gate?(nil, neili_low, app)
    end

    test "余鱼同：先 permit 三问再无条件拒收", %{world: world} do
      app = npc(world, "honghua_yu").meta.apprentice

      assert {:error, "我不收徒，你找其余几位当家的好了。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(), app)

      betray = recruit_student(env: %{"betrayer" => %{"times" => 1}})

      assert {:error, "哼，阁下不忠不信，我们红花会可不会收留。\n"} = SectMaster.recruit_gate?(nil, betray, app)
    end

    test "无尘道长：红花心法先于剑法，两门都不足时不得先报剑法", %{world: world} do
      app = wuchen(world).meta.apprentice

      assert :ok = SectMaster.recruit_gate?(nil, recruit_student(), app)

      assert {:error, "你内功修炼得太差，下去把本门的心法练好了再来。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{skills: %{"honghua-xinfa" => 79, "sword" => 1}}),
                 app
               )

      assert {:error, "你的剑法练成这样，叫我如何传你精深的剑技？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{skills: %{"honghua-xinfa" => 80, "sword" => 79}}),
                 app
               )
    end
  end

  # ---------- 3. 绝招 grant ----------

  describe "16 条 lpc_honghua grant" do
    test "perform_id 全部对齐 LPC（陈家洛 6 条旧错门已修正）", %{world: world} do
      expectations = grant_expectations()
      assert length(expectations) == 16

      for {key, inquiry_key, perform_id} <- expectations do
        cfg = inquiry(ob(world, key), inquiry_key)

        assert cfg["kind"] == "sect_master_grant", "#{key}/#{inquiry_key} kind"
        assert cfg["gate_order"] == "lpc_honghua", "#{key}/#{inquiry_key} gate_order"
        assert cfg["perform_id"] == perform_id, "#{key}/#{inquiry_key} perform_id"
        assert is_binary(cfg["msg_one"]) and byte_size(cfg["msg_one"]) > 0
        assert is_list(cfg["level_order"]) and cfg["level_order"] != []
        assert is_map(cfg["level_deny"]) and map_size(cfg["level_deny"]) > 0
        assert is_list(cfg["improve_skills"]) and cfg["improve_skills"] != []
      end
    end

    test "陆菲青三条同时接受红花会/武当派", %{world: world} do
      lu = npc(world, "honghua_lu")

      for key <- ["玄功无极劲", "三环套月", "金针现影"] do
        assert inquiry(lu, key)["allowed_families"] == ["红花会", "武当派"]
      end
    end

    test "诛天刹神：前置绝招门在有序等级链之前", %{world: world} do
      cfg = inquiry(wuchen(world), "诛天刹神")

      assert cfg["requires_performs"] == ["zhuihun-jian/zhui"]
      assert cfg["requires_perform_deny"] == "这招是由「追魂夺命」演化而来，等你通晓那招后再来吧。"
      assert cfg["level_order"] == ["force", "max-neili", "zhuihun-jian"]

      npc_stats = %{family: "红花会"}

      qualified =
        grant_player(
          gongxian: 1200,
          shen: 80_000,
          skills: %{"zhuihun-jian" => 100}
        )

      assert {:error, "这招是由「追魂夺命」演化而来，等你通晓那招后再来吧。"} =
               SectMaster.inquiry_grant(qualified, npc_stats, cfg)

      learned =
        grant_player(
          gongxian: 1200,
          shen: 80_000,
          skills: %{"zhuihun-jian" => 100},
          performs: MapSet.new(["zhuihun-jian/zhui"])
        )

      assert {:error, "你的内功火候不足，学不成这招。\n"} = SectMaster.inquiry_grant(learned, npc_stats, cfg)
    end

    test "已会 → 同门 → 技能存在 → 贡献 → 侠义，顺序不可颠倒", %{world: world} do
      cfg = inquiry(npc(world, "honghua_chen"), "化蝶")
      npc_stats = %{family: "红花会"}

      known_outsider =
        grant_player(
          family: "少林派",
          performs: MapSet.new(["zhuangzi-wu/hua"])
        )

      assert {:error, "这招我不是已经教给你了吗？"} = SectMaster.inquiry_grant(known_outsider, npc_stats, cfg)

      outsider = grant_player(family: "少林派")

      assert {:error, "和本会素无瓜葛，何出此言？"} = SectMaster.inquiry_grant(outsider, npc_stats, cfg)

      no_skill = grant_player(gongxian: 0, shen: 0, skills: %{})

      assert {:error, "你连庄子舞都没学，还谈什么绝招可言？"} = SectMaster.inquiry_grant(no_skill, npc_stats, cfg)

      low_gongxian = grant_player(gongxian: 999, shen: 0, skills: %{"zhuangzi-wu" => 150})

      assert {:error, "你在会中所作的贡献还不够，这招我不忙传你。"} =
               SectMaster.inquiry_grant(low_gongxian, npc_stats, cfg)

      low_shen = grant_player(gongxian: 1000, shen: 99_999, skills: %{"zhuangzi-wu" => 150})

      assert {:error, "你侠义正事做得不够，这招我不能传你。"} = SectMaster.inquiry_grant(low_shen, npc_stats, cfg)
    end

    test "化蝶：dex → max-neili → 庄子舞 有序等级链与成功返回", %{world: world} do
      cfg = inquiry(npc(world, "honghua_chen"), "化蝶")
      npc_stats = %{family: "红花会"}

      base = [gongxian: 1000, shen: 100_000, skills: %{"zhuangzi-wu" => 150}]

      low_dex = grant_player(base ++ [dex: 31, max_neili: 1])

      assert {:error, "你的身法灵动性不足，学不成这招。\n"} = SectMaster.inquiry_grant(low_dex, npc_stats, cfg)

      low_neili = grant_player(base ++ [dex: 32, max_neili: 1999])

      assert {:error, "你的内力修为不够，学不成这招。\n"} = SectMaster.inquiry_grant(low_neili, npc_stats, cfg)

      low_skill =
        grant_player(
          gongxian: 1000,
          shen: 100_000,
          dex: 32,
          max_neili: 2000,
          skills: %{"zhuangzi-wu" => 149}
        )

      assert {:error, "你的庄子舞还练得不到家，自己下去练练再来吧！\n"} =
               SectMaster.inquiry_grant(low_skill, npc_stats, cfg)

      good =
        grant_player(
          gongxian: 1000,
          shen: 100_000,
          dex: 32,
          max_neili: 2000,
          skills: %{"zhuangzi-wu" => 150}
        )

      assert {:ok, "zhuangzi-wu/hua", 1000} = SectMaster.inquiry_grant(good, npc_stats, cfg)
    end

    test "武当派玩家可向陆菲青求三环套月（双门派白名单）", %{world: world} do
      cfg = inquiry(npc(world, "honghua_lu"), "三环套月")

      wudang =
        grant_player(
          family: "武当派",
          gongxian: 700,
          shen: 60_000,
          skills: %{"rouyun-jian" => 140, "force" => 180, "dodge" => 180}
        )

      assert {:ok, "rouyun-jian/tao", 700} =
               SectMaster.inquiry_grant(wudang, %{family: "红花会"}, cfg)
    end

    test "战神轰天诀保留 3×4 组 improve_skills 重复调用", %{world: world} do
      skills = inquiry(npc(world, "honghua_chen"), "战神轰天诀")["improve_skills"]

      assert Enum.count(skills, &(&1 == "unarmed")) == 3
      assert Enum.count(skills, &(&1 == "baihua-cuoquan")) == 3
      assert Enum.count(skills, &(&1 == "force")) == 3
      assert Enum.count(skills, &(&1 == "zhanshen-xinjing")) == 3
      assert List.last(skills) == "martial-cognize"
    end

    test "kaifeng 无尘三条 msg_one 使用 {npc}/{name}，不残留裸占位符", %{world: world} do
      for key <- ["夺命连环", "追魂夺命", "诛天刹神"] do
        text = inquiry(wuchen(world), key)["msg_one"]
        refute String.contains?(text, "$n")
        refute String.contains?(text, "$N")
      end
    end
  end

  # ---------- 4. 物品与战斗闲聊 ----------

  describe "give_item 与战斗闲聊" do
    test "陈家洛剑盾珠索：师父门先于侠义/技能门", %{world: world} do
      cfg = inquiry(npc(world, "honghua_chen"), "剑盾珠索")

      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "clone_lib:jiansuo"
      assert cfg["master_id"] == "true" or cfg["master_id"] == true
      assert cfg["master_before_gates"] == "true" or cfg["master_before_gates"] == true
      assert cfg["min_shen"] == 80_000
      assert cfg["min_skill_levels"] == %{"jiandun_zhusuo" => 120}
      assert cfg["success"] == "这剑盾珠索你就拿去，多用它行侠仗义，惩奸除恶。"
    end

    test "陆菲青芙蓉金针：共享库存 zhen_count=3 + 双门派 + 非唯一", %{world: world} do
      lu = npc(world, "honghua_lu")
      cfg = inquiry(lu, "芙蓉金针")

      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "kaifeng:jinzhen"
      assert cfg["count"] == "zhen_count"
      assert cfg["unique"] == "false" or cfg["unique"] == false
      assert cfg["allowed_families"] == ["红花会", "武当派"]
      assert cfg["min_skill_levels"] == %{"furong_jinzhen" => 80}
      assert lu.meta.inquiry_state == %{"zhen_count" => 3}
    end

    test "白龙剑：三师父白名单 + 武当派专属拒绝文案", %{world: world} do
      cfg = inquiry(npc(world, "honghua_lu"), "白龙剑")

      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "clone_lib:bailongjian"
      assert cfg["allowed_families"] == ["红花会", "武当派"]
      assert cfg["allowed_master_ids"] == ["chen jialuo", "wuchen daozhang", "zhao banshan"]
      assert cfg["master_before_gates"] == "true" or cfg["master_before_gates"] == true
      assert cfg["min_shen"] == 30_000
      assert cfg["min_skill_levels"] == %{"rouyun_jian" => 150}

      assert cfg["family_denies"] == %{
               "武当派" => "你虽和我同在武当，但这配剑是我随身之物，现大敌当前，不便交予。"
             }
    end

    test "回龙璧：三师父白名单 + 技能门先于侠义门", %{world: world} do
      cfg = inquiry(npc(world, "honghua_zhao"), "回龙璧")

      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "clone_lib:huilongbi"
      assert cfg["allowed_master_ids"] == ["chen jialuo", "wuchen daozhang", "zhao banshan"]
      assert cfg["master_before_gates"] == "true" or cfg["master_before_gates"] == true
      assert cfg["skill_before_shen"] == "true" or cfg["skill_before_shen"] == true
      assert cfg["min_shen"] == 30_000
      assert cfg["min_skill_levels"] == %{"huilong_bifa" => 150}
    end

    test "11 位 clone_lib NPC 战斗闲聊载荷逐字保留", %{world: world} do
      expected = %{
        "honghua_chang1" => ["strike.cui", "powerup", "recover"],
        "honghua_chang2" => ["strike.cui", "powerup", "recover"],
        "honghua_chen" => [
          "unarmed.luan",
          "unarmed.yi",
          "unarmed.hong",
          "whip.qian",
          "whip.fu",
          "dodge.hua",
          "powerup",
          "shield",
          "recover"
        ],
        "honghua_jiang" => ["staff.lun", "powerup", "recover"],
        "honghua_lu" => [
          "unarmed.xuan",
          "sword.tao",
          "throwing.xian",
          "shield",
          "powerup",
          "recover"
        ],
        "honghua_luo" => ["blade.ying", "powerup", "recover"],
        "honghua_shi" => ["staff.lun", "powerup", "recover"],
        "honghua_wen" => ["strike.lei", "powerup", "recover"],
        "honghua_yang" => ["staff.lun", "powerup", "recover"],
        "honghua_yu" => [
          "unarmed.xuan",
          "sword.tao",
          "throwing.xian",
          "shield",
          "powerup",
          "recover"
        ],
        "honghua_zhao" => ["sword.chan", "throwing.cang", "powerup", "recover"]
      }

      assert map_size(expected) == 11

      for {key, payload} <- expected do
        npc_ob = npc(world, key)
        assert npc_ob.meta.chat_chance_combat == 100, "#{key} chat_chance_combat"
        assert npc_ob.meta.chat_msg_combat == payload, "#{key} chat_msg_combat"
      end
    end

    test "kaifeng 无尘道长战斗闲聊载荷", %{world: world} do
      npc_ob = wuchen(world)

      assert npc_ob.meta.chat_chance_combat == 100

      assert npc_ob.meta.chat_msg_combat == [
               "sword.zhu",
               "sword.zhui",
               "unarmed.lian",
               "powerup",
               "recover"
             ]
    end
  end
end

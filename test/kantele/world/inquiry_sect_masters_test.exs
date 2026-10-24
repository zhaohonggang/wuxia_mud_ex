defmodule Kantele.World.InquirySectMastersTest do
  @moduledoc """
  P5-4at：门派师父 `ask_skillN` 绝招问询的数据回填 + 门控联验。

  覆盖 5 个 NPC（LPC `kungfu/class/**` 的 ask_skill 闭包）：
    - heimuya/ren     任我行   5 门（日月神教）
    - kaifeng/wuchen  无尘道长 3 门（红花会）
    - xuedao/baoxiang 宝象     1 门（血刀门）
    - xuedao/shengdi  胜谛     1 门（血刀门）
    - guanwai/pingsi  平四     4 条纯文本问询 + 3 条传送服务（出关/办事/出去 → teleport_service）

  断言分两层：① UCL 数据经 Loader 归一后的门控字段（含 min_levels 的
  `_`→`-` 键归一）；② 用**加载出来的真实配置**喂 `SectMaster.inquiry_grant/3`，
  验证同门派玩家过门 / 差贡献、杀气、内力时各走哪条拒绝文案。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster

  setup_all do
    %{world: Kantele.World.Loader.load()}
  end

  # ---- NPC 定位（角色 id 是加载时生成的哈希，按 名字 + 房间 找） ----

  defp npc(world, name, room_id) do
    Enum.find(world.characters, fn c -> c.name == name and c.room_id == room_id end)
  end

  defp inquiry(npc, key), do: npc.meta.inquiries[key]

  # 同门派弟子（门派名按 NPC 传入；技能/贡献/杀气/内力按用例覆盖）
  # family / max_neili 不是 %Stats{} 字段：inquiry_grant 的宿主由调用方
  # （npc_script_event.stats_with_family/1）补进 map，这里如实镜像。
  defp disciple(overrides \\ %{}) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, nil)
    |> Map.put(:max_neili, 0)
    |> Map.merge(overrides)
  end

  describe "UCL 数据回填（Loader 归一后）" do
    test "任我行 5 门绝招：门控字段与 LPC ask_skill1..5 一致", %{world: world} do
      npc = npc(world, "任我行", "heimuya:chengdedian")
      assert npc, "任我行应随世界加载（heimuya:chengdedian）"
      assert npc.meta.teach.family == "日月神教"

      expected = [
        {"天地归元", "yuanshi-jian/gui", 500, -120_000, nil, %{"force" => 200, "yuanshi-jian" => 140}, 500},
        {"天旋地转", "yuanshi-jian/xuan", 1400, -130_000, nil, %{"force" => 260, "yuanshi-jian" => 180}, 1400},
        {"大巧若拙", "guzhuo-zhang/zhuo", 600, -120_000, 1800, %{"force" => 220, "guzhuo-zhang" => 150}, 600},
        {"大智若愚", "guzhuo-zhang/yu", 1200, -150_000, 2800, %{"force" => 260, "guzhuo-zhang" => 180}, 1200},
        {"反璞归真", "guzhuo-zhang/zhen", 2200, -200_000, 3600, %{"force" => 300, "guzhuo-zhang" => 220}, 2200}
      ]

      for {key, perform_id, gongxian, max_shen, neili, levels, cost} <- expected do
        cfg = inquiry(npc, key)
        assert cfg, "任我行应能回答「#{key}」"

        assert cfg["perform_id"] == perform_id
        assert cfg["skill"] == String.split(perform_id, "/") |> List.first()
        assert cfg["min_gongxian"] == gongxian
        assert cfg["max_shen"] == max_shen
        assert cfg["cost_gongxian"] == cost
        # min_levels 键由 loader 归一为连字符（对齐 Stats.skills）
        assert cfg["min_levels"] == levels

        if neili do
          assert cfg["min_max_neili"] == neili
        else
          refute Map.has_key?(cfg, "min_max_neili")
        end

        # LPC 每招独立文案（*_deny 覆盖）
        assert cfg["family_deny"] == "你又不是我日月神教的，跑来捣什么乱？"
        assert cfg["max_shen_deny"] == "你这样心慈手软，就算学会这招又有什么用？"
        assert cfg["maxed"] == "这一招我不是已经教过你了吗？"
      end

      # 原始剑法两招 / 古拙掌法三招的技能未学文案不同
      assert inquiry(npc, "天地归元")["skill_deny"] == "你连原始剑法都没学，还谈什么绝招可言？"
      assert inquiry(npc, "大巧若拙")["skill_deny"] == "你连古拙掌法都没学，何谈绝招可言？"
    end

    test "无尘道长 3 门绝招：min_shen 下限 + 内力门槛", %{world: world} do
      npc = npc(world, "无尘道长", "kaifeng:hh_jianlou1")
      assert npc, "无尘道长应随世界加载（kaifeng:hh_jianlou1）"
      assert npc.meta.teach.family == "红花会"

      lian = inquiry(npc, "夺命连环")
      assert lian["perform_id"] == "lianhuan-mizongtui/lian"
      assert lian["skill"] == "lianhuan-mizongtui"
      assert lian["min_gongxian"] == 600
      assert lian["min_shen"] == 50_000
      assert lian["min_max_neili"] == 1800
      assert lian["min_levels"] == %{"force" => 150, "dodge" => 150, "lianhuan-mizongtui" => 120}
      assert lian["cost_gongxian"] == 600
      assert lian["family_deny"] == "大侠和本会素无瓜葛，何出此言？"
      assert lian["shen_deny"] == "你侠义正事做得不够，这招我不能传你。"

      zhui = inquiry(npc, "追魂夺命")
      assert zhui["perform_id"] == "zhuihun-jian/zhui"
      assert zhui["min_shen"] == 35_000
      assert zhui["min_max_neili"] == 800

      zhu = inquiry(npc, "诛天刹神")
      assert zhu["perform_id"] == "zhuihun-jian/zhu"
      assert zhu["min_shen"] == 80_000
      assert zhu["min_max_neili"] == 1800
      assert zhu["min_levels"] == %{"force" => 200, "zhuihun-jian" => 160}
    end

    test "宝象/胜谛 各 1 门：血刀门同门校验（teach.family）", %{world: world} do
      baoxiang = npc(world, "宝象", "xuedao:shandong2")
      assert baoxiang, "宝象应随世界加载（xuedao:shandong2）"
      assert baoxiang.meta.teach.family == "血刀门"

      huo = inquiry(baoxiang, "流星火雨")
      assert huo["perform_id"] == "honglian-dao/huo"
      assert huo["skill"] == "honglian-dao"
      assert huo["min_gongxian"] == 80
      assert huo["max_shen"] == -8000
      assert huo["min_max_neili"] == 800
      assert huo["min_levels"] == %{"force" => 120, "honglian-dao" => 80}
      assert huo["family_deny"] == "你又不是我血刀门的，再罗嗦我宰了你！"

      shengdi = npc(world, "胜谛", "xuedao:sroad9")
      assert shengdi, "胜谛应随世界加载（xuedao:sroad9）"
      assert shengdi.meta.teach.family == "血刀门"

      kai = inquiry(shengdi, "冰河开封")
      assert kai["perform_id"] == "xueshan-dao/kai"
      assert kai["min_gongxian"] == 50
      assert kai["max_shen"] == -3000
      assert kai["min_max_neili"] == 600
      assert kai["min_levels"] == %{"force" => 100, "xueshan-dao" => 80}
    end

    test "平四 4 条纯文本问询 + 3 条传送服务（出关/办事/出去 已回填 teleport_service）", %{world: world} do
      pingsi = npc(world, "平四", "guanwai:xiaoyuan")
      assert pingsi, "平四应随世界加载（guanwai:xiaoyuan）"

      assert inquiry(pingsi, "阎基") == "阎基…哼…这个狗贼。"
      assert inquiry(pingsi, "胡一刀") == "那……那是老主人，唉。"
      assert inquiry(pingsi, "苗人凤") == "苗大侠可不是坏人。"
      assert inquiry(pingsi, "赵半山") == "他对我家主人的交情那是没得说的。"

      # 出关/办事/出去 已回填为 kind="teleport_service" 传送服务
      for key <- ~w(出关 办事 出去) do
        cfg = inquiry(pingsi, key)
        assert cfg, "平四应能回答「#{key}」"
        assert cfg["kind"] == "teleport_service"
        assert cfg["target_room"] == "beijing:majiu"
        assert cfg["startroom"] == "guanwai:xiaoyuan"
        assert cfg["family"] == "关外胡家"
        assert cfg["vision_name"] == "平四"
        assert cfg["success"] == "马车已备，请上车。"
        assert cfg["family_deny"] == "你自己没长腿么？"
        assert cfg["room_deny"] == "我这里还有事，你就自己走回去吧。"
      end
    end

    test "苗人凤 10 门绝招：中原苗家门派 + min_shen 侠义下限 + 内力门槛", %{world: world} do
      npc = npc(world, "苗人凤", "zhongzhou:miaojia_houting")
      assert npc, "苗人凤应随世界加载（zhongzhou:miaojia_houting）"
      assert npc.meta.teach.family == "中原苗家"

      dan = inquiry(npc, "丹阳劲")
      assert dan["perform_id"] == "miaojia-zhang/dan"
      assert dan["skill"] == "miaojia-zhang"
      assert dan["min_gongxian"] == 50
      assert dan["min_shen"] == 2000
      assert dan["min_max_neili"] == 200
      assert dan["min_levels"] == %{"force" => 50, "miaojia-zhang" => 40}
      assert dan["cost_gongxian"] == 50
      assert dan["family_deny"] == "给我走开！"
      assert dan["skill_deny"] == "你连苗家掌法都未学，何谈绝招可言？"

      gan = inquiry(npc, "流星赶月")
      assert gan["perform_id"] == "miaojia-jian/gan"
      assert gan["min_gongxian"] == 2200
      assert gan["min_shen"] == 35_000
      assert gan["min_max_neili"] == 3000
      assert gan["min_levels"] == %{"force" => 280, "miaojia-jian" => 200}
      assert gan["skill_deny"] == "你连苗家剑法都未学，何谈绝招可言？"

      # 4 条纯字符串问询（batch-2 回填）仍保留
      assert inquiry(npc, "胡一刀") == "当年我中了奸人毒计杀害了他，令我遗憾终生！"
    end

    test "桑三娘 3 门绝招：日月神教 + max_shen 阴面门派", %{world: world} do
      npc = npc(world, "桑三娘", "heimuya:tian1")
      assert npc, "桑三娘应随世界加载（heimuya:tian1）"
      assert npc.meta.teach.family == "日月神教"

      po = inquiry(npc, "破靛神砂")
      assert po["perform_id"] == "lansha-shou/po"
      assert po["skill"] == "lansha-shou"
      assert po["min_gongxian"] == 200
      assert po["max_shen"] == -20_000
      assert po["min_levels"] == %{"force" => 150, "lansha-shou" => 100}
      assert po["cost_gongxian"] == 200
      assert po["max_shen_deny"] == "你这样心慈手软，就算学会这招又有什么用？"

      luo = inquiry(npc, "星罗棋布")
      assert luo["perform_id"] == "heixue-shenzhen/luo"
      assert luo["max_shen"] == -35_000
      assert luo["min_levels"] == %{"force" => 200, "heixue-shenzhen" => 140}
      assert luo["skill_deny"] == "你连黑血神针都没学，还谈什么绝招可言？"

      cang = inquiry(npc, "天蝎藏针")
      assert cang["perform_id"] == "jifeng-cixuefa/cang"
      assert cang["max_shen"] == -15_000
      assert cang["min_levels"] == %{"force" => 120, "dodge" => 120, "jifeng-cixuefa" => 100}
    end

    test "刘处玄 连环掌/重阳连环掌 同闭包：全真教 + min_shen 阳面门派", %{world: world} do
      npc = npc(world, "刘处玄", "quanzhen:jingxiushi")
      assert npc, "刘处玄应随世界加载（quanzhen:jingxiushi）"
      assert npc.meta.teach.family == "全真教"

      lian = inquiry(npc, "连环掌")
      assert lian["perform_id"] == "chongyang-shenzhang/lian"
      assert lian["skill"] == "chongyang-shenzhang"
      assert lian["min_gongxian"] == 100
      assert lian["min_shen"] == 10_000
      assert lian["min_levels"] == %{"force" => 120, "chongyang-shenzhang" => 100}
      assert lian["cost_gongxian"] == 100
      assert lian["shen_deny"] == "你的侠义正事还做得不够，这招我暂时还不能传你。"

      # 重阳连环掌 是同一闭包 ask_skill1 的第二个问询键，配置相同
      lian2 = inquiry(npc, "重阳连环掌")
      assert lian2["perform_id"] == "chongyang-shenzhang/lian"
      assert lian2["min_shen"] == 10_000
    end

    test "商剑鸣 7 门绝招：商家堡 + max_shen 阴面门派（ask_skill1-7 均为绝招授艺）", %{world: world} do
      npc = npc(world, "商剑鸣", "shaolin:shang_dating")
      assert npc, "商剑鸣应随世界加载（shaolin:shang_dating）"
      assert npc.meta.teach.family == "商家堡"

      # 7 招：{key, perform_id, min_gongxian, max_shen, min_levels, cost}
      expected = [
        {"八卦震", "wai-bagua/zhen", 100, -5000, %{"force" => 100, "wai-bagua" => 60}, 100},
        {"混沌初开", "baisheng-quan/kai", 300, -20000, %{"force" => 140, "baisheng-quan" => 100}, 300},
        {"金莲幻生", "jinbiao-jue/huan", 300, -15000, %{"force" => 140, "jinbiao-jue" => 100}, 300},
        {"神卦天印", "bazhen-zhang/yin", 500, -20000, %{"force" => 180, "bazhen-zhang" => 130}, 500},
        {"寒芒暴卷", "shangjia-dao/juan", 80, -1000, %{"force" => 80, "shangjia-dao" => 50}, 80},
        {"劈天神芒", "bagua-dao/mang", 1000, -50000, %{"force" => 200, "bagua-dao" => 140, "wai-bagua" => 140}, 1000},
        {"杀龙无悔", "bagua-dao/sha", 1800, -80000, %{"force" => 250, "bagua-dao" => 180}, 1800}
      ]

      for {key, perform_id, gongxian, max_shen, levels, cost} <- expected do
        cfg = inquiry(npc, key)
        assert cfg, "商剑鸣应能回答「#{key}」"

        assert cfg["perform_id"] == perform_id
        assert cfg["skill"] == String.split(perform_id, "/") |> List.first()
        assert cfg["min_gongxian"] == gongxian
        assert cfg["max_shen"] == max_shen
        assert cfg["cost_gongxian"] == cost
        assert cfg["min_levels"] == levels
      end

      # 共享拒绝文案（阴面门派 max_shen_deny / 同门 family_deny）
      zhen = inquiry(npc, "八卦震")
      assert zhen["family_deny"] == "与我商家堡素无来往，何出此言？"
      assert zhen["max_shen_deny"] == "哼！你这样的心慈手软之徒，就算学了这招又有何用？"
      assert zhen["skill_deny"] == "你连外八卦都没学，谈什么绝招？"

      # 各招「已会」文案不同（LPC 直搬）
      assert inquiry(npc, "八卦震")["maxed"] == "自己下去练，罗嗦什么！"
      assert inquiry(npc, "神卦天印")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "杀龙无悔")["maxed"] == "唉…你自己下去练吧。"

      # 2 条纯字符串问询（LPC 直答）仍保留
      assert inquiry(npc, "胡一刀") == "哦？听说此人刀法甚是了得，可惜我没见过他。"
      assert inquiry(npc, "苗人凤") == "哼，这贼鸟厮居然敢号称天下无敌，改天一定要去会会。"

      # 紫金八卦刀（item_grant，P5-4ay 回填）：kind=give_item，master_id + max_shen + min_skill 门控
      dao = inquiry(npc, "紫金八卦刀")
      assert dao["kind"] == "give_item"
      assert dao["item"] == "clone_lib:baguadao"
      assert dao["unique"] == "true"
      assert dao["family"] == "商家堡"
      assert dao["master_id"] == "true"
      assert dao["max_shen"] == -50000
      assert dao["min_skill_levels"] == %{"bagua_dao" => 150}
      assert dao["max_shen_deny"] == "像你这样的心慈手软之辈，这刀你不用也罢。"
      assert dao["master_deny"] == "只有我的弟子才配用这八卦刀，你别拿去丢脸。"

      # 天刀八势（give_letter，P5-4ay 回填）：kind=give_item，perform_id + cost_gongxian + 多重门控
      letter = inquiry(npc, "天刀八势")
      assert letter["kind"] == "give_item"
      assert letter["item"] == "clone_lib:sjmletter"
      assert letter["unique"] == "true"
      assert letter["family"] == "商家堡"
      assert letter["perform_id"] == "bagua-dao/tian"
      assert letter["cost_gongxian"] == 2200
      assert letter["min_gongxian"] == 2200
      assert letter["max_neili"] == 3200
      assert letter["min_skill_levels"] == %{"bagua_dao" => 200, "wai_bagua" => 200, "nei_bagua" => 200}
      assert letter["maxed"] == "你不是已经会了吗？"
      assert letter["already"] == "快到镇远镖局找我师傅去吧！"
      assert letter["min_gongxian_deny"] == "你在镖局内碌碌无为，这一招我暂时还不能传你。"
      assert letter["max_neili_deny"] == "你的内力修为不足，施展不出这招，等你内力有所攀升后再来找我吧。"
      assert letter["min_skill_deny"] == "你的八卦刀法还练得不到家，自己下去练练再来吧！"
    end
  end

  describe "门控联验（真实配置 + inquiry_grant/3）" do
    test "日月神教弟子全达标 → 学会「天地归元」并扣 500 贡献", %{world: world} do
      cfg = inquiry(npc(world, "任我行", "heimuya:chengdedian"), "天地归元")

      player =
        disciple(%{
          skills: %{"yuanshi-jian" => 140, "force" => 200},
          gongxian: 500,
          shen: -120_000,
          family: "日月神教"
        })

      assert {:ok, "yuanshi-jian/gui", 500} =
               SectMaster.inquiry_grant(player, %{family: "日月神教"}, cfg)
    end

    test "杀气不够阴（shen > -120000）→ max_shen_deny", %{world: world} do
      cfg = inquiry(npc(world, "任我行", "heimuya:chengdedian"), "天地归元")

      player =
        disciple(%{
          skills: %{"yuanshi-jian" => 140, "force" => 200},
          gongxian: 500,
          shen: -119_999,
          family: "日月神教"
        })

      assert {:error, "你这样心慈手软，就算学会这招又有什么用？"} =
               SectMaster.inquiry_grant(player, %{family: "日月神教"}, cfg)
    end

    test "内力不足（大巧若拙 1800）→ max_neili_deny", %{world: world} do
      cfg = inquiry(npc(world, "任我行", "heimuya:chengdedian"), "大巧若拙")

      player =
        disciple(%{
          skills: %{"guzhuo-zhang" => 150, "force" => 220},
          gongxian: 600,
          shen: -120_000,
          family: "日月神教",
          max_neili: 1799
        })

      assert {:error, "你的内力太差，怎么修炼上乘武功？"} =
               SectMaster.inquiry_grant(player, %{family: "日月神教"}, cfg)

      # 同一份配置，内力补齐即过门（min_max_neili 门控真实生效）
      assert {:ok, "guzhuo-zhang/zhuo", 600} =
               SectMaster.inquiry_grant(
                 %{player | max_neili: 1800},
                 %{family: "日月神教"},
                 cfg
               )
    end

    test "非红花会弟子 → family_deny（含敬称）", %{world: world} do
      cfg = inquiry(npc(world, "无尘道长", "kaifeng:hh_jianlou1"), "夺命连环")

      player =
        disciple(%{
          skills: %{"lianhuan-mizongtui" => 120, "force" => 150, "dodge" => 150},
          gongxian: 600,
          shen: 50_000,
          max_neili: 1800,
          family: "武当派"
        })

      assert {:error, "大侠和本会素无瓜葛，何出此言？"} =
               SectMaster.inquiry_grant(player, %{family: "红花会"}, cfg)
    end

    test "侠义不足（shen < 50000）→ shen_deny", %{world: world} do
      cfg = inquiry(npc(world, "无尘道长", "kaifeng:hh_jianlou1"), "夺命连环")

      player =
        disciple(%{
          skills: %{"lianhuan-mizongtui" => 120, "force" => 150, "dodge" => 150},
          gongxian: 600,
          shen: 49_999,
          max_neili: 1800,
          family: "红花会"
        })

      assert {:error, "你侠义正事做得不够，这招我不能传你。"} =
               SectMaster.inquiry_grant(player, %{family: "红花会"}, cfg)
    end

    test "血刀门外派 + 杀气过高 → 宝象 family_deny 先拦", %{world: world} do
      cfg = inquiry(npc(world, "宝象", "xuedao:shandong2"), "流星火雨")

      player =
        disciple(%{
          skills: %{"honglian-dao" => 80, "force" => 120},
          gongxian: 80,
          shen: 1000,
          max_neili: 800,
          family: "少林派"
        })

      assert {:error, "你又不是我血刀门的，再罗嗦我宰了你！"} =
               SectMaster.inquiry_grant(player, %{family: "血刀门"}, cfg)

      # 同门但心慈手软 → max_shen_deny
      assert {:error, "你这样心慈手软，就算学会这招又有什么用？"} =
               SectMaster.inquiry_grant(%{player | family: "血刀门"}, %{family: "血刀门"}, cfg)
    end

    test "中原苗家弟子全达标 → 学会「丹阳劲」并扣 50 贡献", %{world: world} do
      cfg = inquiry(npc(world, "苗人凤", "zhongzhou:miaojia_houting"), "丹阳劲")

      player =
        disciple(%{
          skills: %{"miaojia-zhang" => 40, "force" => 50},
          gongxian: 50,
          shen: 2000,
          max_neili: 200,
          family: "中原苗家"
        })

      assert {:ok, "miaojia-zhang/dan", 50} =
               SectMaster.inquiry_grant(player, %{family: "中原苗家"}, cfg)
    end

    test "侠义不足（shen < 2000）→ shen_deny；非苗家 → family_deny", %{world: world} do
      cfg = inquiry(npc(world, "苗人凤", "zhongzhou:miaojia_houting"), "丹阳劲")

      low_shen =
        disciple(%{
          skills: %{"miaojia-zhang" => 40, "force" => 50},
          gongxian: 50,
          shen: 1999,
          max_neili: 200,
          family: "中原苗家"
        })

      assert {:error, "你侠义正事做得不够，这招我先不忙传你。"} =
               SectMaster.inquiry_grant(low_shen, %{family: "中原苗家"}, cfg)

      outsider =
        disciple(%{
          skills: %{"miaojia-zhang" => 40, "force" => 50},
          gongxian: 50,
          shen: 2000,
          max_neili: 200,
          family: "武当派"
        })

      assert {:error, "给我走开！"} =
               SectMaster.inquiry_grant(outsider, %{family: "中原苗家"}, cfg)
    end

    test "桑三娘 max_shen 阴面门派：shen > -20000 → max_shen_deny；够阴过门", %{world: world} do
      cfg = inquiry(npc(world, "桑三娘", "heimuya:tian1"), "破靛神砂")

      too_good =
        disciple(%{
          skills: %{"lansha-shou" => 100, "force" => 150},
          gongxian: 200,
          shen: -19_999,
          family: "日月神教"
        })

      assert {:error, "你这样心慈手软，就算学会这招又有什么用？"} =
               SectMaster.inquiry_grant(too_good, %{family: "日月神教"}, cfg)

      evil =
        disciple(%{
          skills: %{"lansha-shou" => 100, "force" => 150},
          gongxian: 200,
          shen: -20_000,
          family: "日月神教"
        })

      assert {:ok, "lansha-shou/po", 200} =
               SectMaster.inquiry_grant(evil, %{family: "日月神教"}, cfg)
    end

    test "商剑鸣 max_shen 阴面门派：shen > 阈值 → max_shen_deny；够阴过门（八卦震 / 杀龙无悔）", %{world: world} do
      npc = npc(world, "商剑鸣", "shaolin:shang_dating")

      zhen = inquiry(npc, "八卦震")

      too_good =
        disciple(%{
          skills: %{"wai-bagua" => 60, "force" => 100},
          gongxian: 100,
          shen: -4999,
          family: "商家堡"
        })

      assert {:error, "哼！你这样的心慈手软之徒，就算学了这招又有何用？"} =
               SectMaster.inquiry_grant(too_good, %{family: "商家堡"}, zhen)

      evil =
        disciple(%{
          skills: %{"wai-bagua" => 60, "force" => 100},
          gongxian: 100,
          shen: -5000,
          family: "商家堡"
        })

      assert {:ok, "wai-bagua/zhen", 100} =
               SectMaster.inquiry_grant(evil, %{family: "商家堡"}, zhen)

      # 杀龙无悔：最高门槛（gongxian 1800 / shen -80000 / bagua-dao 180 / force 250）
      sha = inquiry(npc, "杀龙无悔")

      below =
        disciple(%{
          skills: %{"bagua-dao" => 180, "force" => 250},
          gongxian: 1800,
          shen: -79_999,
          family: "商家堡"
        })

      assert {:error, "哼！你这样的心慈手软之徒，就算学了这招又有何用？"} =
               SectMaster.inquiry_grant(below, %{family: "商家堡"}, sha)

      full =
        disciple(%{
          skills: %{"bagua-dao" => 180, "force" => 250},
          gongxian: 1800,
          shen: -80_000,
          family: "商家堡"
        })

      assert {:ok, "bagua-dao/sha", 1800} =
               SectMaster.inquiry_grant(full, %{family: "商家堡"}, sha)
    end
  end
end

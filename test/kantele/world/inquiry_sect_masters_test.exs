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

  # 镜像 npc_shop_event.teach_family/1 与 handler 的 npc_stats：inquiry_grant 的
  # 同门校验读 npc.family，生产路径由 `%{family: teach.family}` 注入（NPC struct 无顶层
  # :family）。测试喂真实加载的 npc 时须同构，否则 same_family? 恒真、family 门不触发。
  defp npc_stats(npc), do: %{family: (npc.meta.teach || %{}).family}

  describe "UCL 数据回填（Loader 归一后）" do
    test "任我行 5 门绝招：门控字段与 LPC ask_skill1..5 一致", %{world: world} do
      npc = npc(world, "任我行", "heimuya:chengdedian")
      assert npc, "任我行应随世界加载（heimuya:chengdedian）"
      assert npc.meta.teach.family == "日月神教"

      expected = [
        {"天地归元", "yuanshi-jian/gui", 500, -120_000, nil, %{"force" => 200, "yuanshi-jian" => 140},
         500},
        {"天旋地转", "yuanshi-jian/xuan", 1400, -130_000, nil,
         %{"force" => 260, "yuanshi-jian" => 180}, 1400},
        {"大巧若拙", "guzhuo-zhang/zhuo", 600, -120_000, 1800,
         %{"force" => 220, "guzhuo-zhang" => 150}, 600},
        {"大智若愚", "guzhuo-zhang/yu", 1200, -150_000, 2800,
         %{"force" => 260, "guzhuo-zhang" => 180}, 1200},
        {"反璞归真", "guzhuo-zhang/zhen", 2200, -200_000, 3600,
         %{"force" => 300, "guzhuo-zhang" => 220}, 2200}
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

      # 5 条 item_grant 问询（腾龙剑 / 剑谱上下册）：kind=give_item 门控字段
      tenglong = inquiry(npc, "腾龙剑")
      assert tenglong["kind"] == "give_item"
      assert tenglong["item"] == "clone_lib:tenglongjian"
      assert tenglong["unique"] == "true"
      assert tenglong["family"] == "中原苗家"
      assert tenglong["master_id"] == "true"
      assert tenglong["min_skill_levels"] == %{"sword" => 150}
      assert tenglong["vision_name"] == "苗人凤"
      assert tenglong["success"] == "这腾龙剑你拿去吧，切莫用它为非作歹。"
      assert tenglong["already"] == "腾龙剑现在不就是你拿着在用吗？"
      assert tenglong["family_deny"] == "给我走开！"
      assert tenglong["master_deny"] == "你又不是我的弟子，跟我罗嗦些什么？"
      assert tenglong["min_skill_deny"] == "你剑法都没练好，就算利剑在手又有何用？"

      jianpu_shang = inquiry(npc, "剑谱上册")
      assert jianpu_shang["kind"] == "give_item"
      assert jianpu_shang["item"] == "clone_lib:miaojia1"
      assert jianpu_shang["unique"] == "true"
      assert jianpu_shang["family"] == "中原苗家"
      assert jianpu_shang["master_id"] == "true"
      assert jianpu_shang["min_combat_exp"] == 10000
      assert jianpu_shang["max_skill_levels"] == %{"suqin-beijian" => 119}
      assert jianpu_shang["vision_name"] == "苗人凤"
      assert jianpu_shang["success"] == "这本剑谱你就拿去看吧，可要仔细阅读。"
      assert jianpu_shang["already"] == "我苗家的家传剑谱不就是你拿着在看吗？"
      assert jianpu_shang["family_deny"] == "给我走开！"
      assert jianpu_shang["master_deny"] == "你又不是我的弟子，跟我罗嗦些什么？"
      assert jianpu_shang["min_exp_deny"] == "你现在经验太浅，这本剑谱对你来说过于深奥了。"
      assert jianpu_shang["max_skill_deny"] == "你的剑法根基已经很扎实了，这剑谱还是留给后辈们吧。"

      # 「上册」是「剑谱上册」的别名，配置应当一致
      shang_alias = inquiry(npc, "上册")
      assert shang_alias["kind"] == "give_item"
      assert shang_alias["item"] == "clone_lib:miaojia1"
      assert shang_alias["min_combat_exp"] == 10000

      jianpu_xia = inquiry(npc, "剑谱下册")
      assert jianpu_xia["kind"] == "give_item"
      assert jianpu_xia["item"] == "clone_lib:miaojia2"
      assert jianpu_xia["unique"] == "true"
      assert jianpu_xia["family"] == "中原苗家"
      assert jianpu_xia["master_id"] == "true"
      assert jianpu_xia["min_combat_exp"] == 300_000
      assert jianpu_xia["max_skill_levels"] == %{"sword" => 199}
      assert jianpu_xia["vision_name"] == "苗人凤"
      assert jianpu_xia["success"] == "今日我将这剑谱交给你，可别落入奸人之手。"
      assert jianpu_xia["already"] == "我苗家的家传剑谱不就是你拿着在看吗？"
      assert jianpu_xia["family_deny"] == "给我走开！"
      assert jianpu_xia["master_deny"] == "你又不是我的弟子，跟我罗嗦些什么？"
      assert jianpu_xia["min_exp_deny"] == "你现在经验太浅，这本剑谱对你来说过于深奥了。"
      assert jianpu_xia["max_skill_deny"] == "你的剑法造诣已算得上是登峰造极了，这剑谱还是留给后辈们吧。"

      # 「下册」是「剑谱下册」的别名，配置应当一致
      xia_alias = inquiry(npc, "下册")
      assert xia_alias["kind"] == "give_item"
      assert xia_alias["item"] == "clone_lib:miaojia2"
      assert xia_alias["min_combat_exp"] == 300_000
    end

    test "苗人凤 收徒/授艺/装备/战斗闲聊/临时属性（Task #880 回填）", %{world: world} do
      npc = npc(world, "苗人凤", "zhongzhou:miaojia_houting")
      assert npc, "苗人凤应随世界加载（zhongzhou:miaojia_houting）"

      # —— 收徒硬门（miao.h permit_recruit + 姓名门占位）——
      apprentice = npc.meta.apprentice
      assert apprentice.family == "中原苗家"
      assert apprentice.required_born_family == "中原苗家"
      assert apprentice.born_family_deny == "我苗家向来便不收容外人。"
      assert apprentice.permit_recruit == true
      assert apprentice.betray_sect_deny == "你反复无常，我不能收你为徒！"
      assert apprentice.other_family_deny == "你既已在外面投师学艺，就应有所作为，又跑回来作甚？"

      # accept_msg 无字面 \n（CommandView "text" 逐字渲染，字面 \n 会露字面量）
      assert apprentice.accept_msg =~ "可是这祖传三十七势苗家剑就在我处失传，未免太过不孝。"
      refute apprentice.accept_msg =~ "\\n"

      # —— no_teach 三形态（条件解锁 map + 纯字符串硬拒）——
      teach = npc.meta.teach

      assert Enum.sort(teach.no_teach) ==
               ["chongtian-zhang", "hujia-daofa", "miaojia-jian", "tianlong-jian"]

      assert teach.no_teach_deny["hujia-daofa"] == "胡家刀法乃是我当年从胡世兄处习得，不便外传。"

      assert teach.no_teach_unlock["miaojia-jian"] == %{
               mark: "can_learn/miao/miaojia-jian",
               min_exp: 400_000,
               learned: "既然今日你能达此地步，我就传你苗家剑法。",
               locked: "你此时功力太浅，我还是先传授你些简单的剑法。"
             }

      assert teach.no_teach_unlock["tianlong-jian"].mark == "can_learn/miao/tianlong-jian"
      assert teach.no_teach_unlock["tianlong-jian"].min_exp == 120_000
      assert teach.no_teach_unlock["chongtian-zhang"].min_exp == 100_000

      # —— 条件解锁行为（SectMaster.teachable? 直测，exp 严格大于阈值）——
      high = %{stats: %Stats{combat_exp: 500_000}}

      assert {:unlock, "既然今日你能达此地步，我就传你苗家剑法。", "can_learn/miao/miaojia-jian"} =
               SectMaster.teachable?(npc, high, "miaojia-jian")

      low = %{stats: %Stats{combat_exp: 1_000}}

      assert {:error, "你此时功力太浅，我还是先传授你些简单的剑法。"} = SectMaster.teachable?(npc, low, "miaojia-jian")

      assert {:error, hujia_msg} = SectMaster.teachable?(npc, high, "hujia-daofa")
      assert String.trim(hujia_msg) == "胡家刀法乃是我当年从胡世兄处习得，不便外传。"

      # —— 三 grant 侠义下限（#879 give_item 已支持 min_shen）——
      assert inquiry(npc, "腾龙剑")["min_shen"] == 20_000
      assert inquiry(npc, "腾龙剑")["shen_deny"] == "你非我侠义中人，这腾龙剑我不能给你。"
      assert inquiry(npc, "剑谱上册")["min_shen"] == 15_000
      assert inquiry(npc, "剑谱下册")["min_shen"] == 50_000

      # —— 随身装备（carry：腾龙剑 + 布衣）——
      assert npc.meta.carry == ["clone_lib:tenglongjian", "clone_lib:cloth"]

      # —— 战斗闲聊（chat_chance_combat / chat_msg_combat）——
      assert npc.meta.chat_chance_combat == 120

      assert npc.meta.chat_msg_combat == [
               "sword.zhai",
               "sword.zhu",
               "sword.jian",
               "sword.gan",
               "strike.zhan",
               "claw.tan",
               "recover",
               "powerup"
             ]

      # —— 临时属性（combat.apply：damage/unarmed_damage/armor）——
      temp = npc.meta.combat.temp
      assert Map.get(temp, :damage) == 100
      assert Map.get(temp, :unarmed_damage) == 100
      assert Map.get(temp, :armor) == 200
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
        {"混沌初开", "baisheng-quan/kai", 300, -20000, %{"force" => 140, "baisheng-quan" => 100},
         300},
        {"金莲幻生", "jinbiao-jue/huan", 300, -15000, %{"force" => 140, "jinbiao-jue" => 100}, 300},
        {"神卦天印", "bazhen-zhang/yin", 500, -20000, %{"force" => 180, "bazhen-zhang" => 130}, 500},
        {"寒芒暴卷", "shangjia-dao/juan", 80, -1000, %{"force" => 80, "shangjia-dao" => 50}, 80},
        {"劈天神芒", "bagua-dao/mang", 1000, -50000,
         %{"force" => 200, "bagua-dao" => 140, "wai-bagua" => 140}, 1000},
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

      assert letter["min_skill_levels"] == %{
               "bagua_dao" => 200,
               "wai_bagua" => 200,
               "nei_bagua" => 200
             }

      assert letter["maxed"] == "你不是已经会了吗？"
      assert letter["already"] == "快到镇远镖局找我师傅去吧！"
      assert letter["min_gongxian_deny"] == "你在镖局内碌碌无为，这一招我暂时还不能传你。"
      assert letter["max_neili_deny"] == "你的内力修为不足，施展不出这招，等你内力有所攀升后再来找我吧。"
      assert letter["min_skill_deny"] == "你的八卦刀法还练得不到家，自己下去练练再来吧！"
    end

    test "商老太 4 门绝招：商家堡 + max_shen 阴面门派（ask_skill1-4 均为绝招授艺）", %{world: world} do
      npc = npc(world, "商老太", "shaolin:shang_houyuan")
      assert npc, "商老太应随世界加载（shaolin:shang_houyuan）"
      assert npc.meta.teach.family == "商家堡"

      # 4 招：{key, perform_id, min_gongxian, max_shen, min_levels, cost}
      expected = [
        {"劈卦拳", "bagua-quan/gua", 100, -10000, %{"force" => 100, "bagua-quan" => 70}, 100},
        {"背心钉", "bagua-zhang/ding", 150, -20000, %{"force" => 120, "bagua-zhang" => 80}, 150},
        {"犀牛望月", "tan-tui/wang", 350, -25000, %{"force" => 150, "tan-tui" => 120}, 350},
        {"天残剑诀", "quemen-jian/can", 60, -5000, %{"force" => 120, "quemen-jian" => 80}, 60}
      ]

      for {key, perform_id, gongxian, max_shen, levels, cost} <- expected do
        cfg = inquiry(npc, key)
        assert cfg, "商老太应能回答「#{key}」"

        assert cfg["perform_id"] == perform_id
        assert cfg["skill"] == String.split(perform_id, "/") |> List.first()
        assert cfg["min_gongxian"] == gongxian
        assert cfg["max_shen"] == max_shen
        assert cfg["cost_gongxian"] == cost
        assert cfg["min_levels"] == levels
      end

      # 共享拒绝文案（阴面门派 max_shen_deny / 同门 family_deny / 贡献门控）
      gua = inquiry(npc, "劈卦拳")
      assert gua["family_deny"] == "与我商家堡素无来往，何出此言？"
      assert gua["max_shen_deny"] == "哼！你这样的心慈手软之徒，就算学了这招又有何用？"
      assert gua["skill_deny"] == "你连八卦拳法都没学，还谈什么绝招可言？"
      assert gua["gongxian_deny"] == "你在我商家堡内碌碌无为，这一招我暂时还不能传你。"

      # 各招「已会」/「学会」文案不同（LPC 直搬）
      assert inquiry(npc, "劈卦拳")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "背心钉")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "犀牛望月")["maxed"] == "自己下去练，罗嗦什么！"
      assert inquiry(npc, "天残剑诀")["maxed"] == "自己下去练，罗嗦什么！"

      assert inquiry(npc, "劈卦拳")["learned"] == "你学会了「劈卦拳」。"
      assert inquiry(npc, "犀牛望月")["learned"] == "你学会了「犀牛望月转回还」。"

      # no_teach：八卦刀由夫君亲传，外八卦经功力闭包解锁（GAP #739 平坦列表）
      assert npc.meta.teach.no_teach == ["bagua-dao", "wai-bagua"]

      # 教学上限与 NPC 自身等级一致（tai.c set_skill）
      assert Map.get(npc.meta.teach.teach_skills, "force") == %{gongxian: 4, max: 160}
      assert Map.get(npc.meta.teach.teach_skills, "bagua-dao") == %{gongxian: 4, max: 180}
      assert Map.get(npc.meta.teach.teach_skills, "tan-tui") == %{gongxian: 4, max: 140}
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

      assert {:error, "大侠和本会素无瓜葛，何出此言？"} = SectMaster.inquiry_grant(player, %{family: "红花会"}, cfg)
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

      assert {:error, "给我走开！"} = SectMaster.inquiry_grant(outsider, %{family: "中原苗家"}, cfg)
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

      assert {:ok, "lansha-shou/po", 200} = SectMaster.inquiry_grant(evil, %{family: "日月神教"}, cfg)
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

      assert {:ok, "wai-bagua/zhen", 100} = SectMaster.inquiry_grant(evil, %{family: "商家堡"}, zhen)

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

      assert {:ok, "bagua-dao/sha", 1800} = SectMaster.inquiry_grant(full, %{family: "商家堡"}, sha)
    end
  end

  describe "华山派 UCL 数据回填（Task #740）" do
    defp huashan_player(overrides \\ %{}) do
      disciple(%{
        skills: %{"huashan-jian" => 160, "kuangfeng-jian" => 140, "force" => 150, "dodge" => 180},
        family: "华山派"
      })
      |> Map.merge(overrides)
    end

    test "成不忧：直授狂风快剑 + 天外飞龙/风扫落叶双招，剑宗上界原样落位", %{world: world} do
      cheng = npc(world, "成不忧", "huashan:jzroad6")
      assert cheng, "成不忧应随世界加载"
      assert cheng.meta.teach.family == "华山派"
      assert map_size(cheng.meta.teach.teach_skills) == 13

      kf = inquiry(cheng, "狂风快剑")
      assert kf["kind"] == "sect_master_teach_skill"
      assert kf["skill"] == "kuangfeng-jian"
      assert kf["max_neili_cap"] == 2000
      assert kf["max_skill_levels"] == %{"force" => 205}
      assert kf["min_skill_levels"] == %{"sword" => 120, "dodge" => 180}
      assert kf["min_skill_deny"]["dodge"] == "你轻功修为不足，无法学习狂风快剑！"

      long = inquiry(cheng, "天外飞龙")
      assert long["perform_id"] == "huashan-jian/long"
      assert long["max_neili_cap"] == 2000
      assert long["max_skill_levels"] == %{"force" => 205}
      assert long["min_levels"] == %{"force" => 150, "huashan-jian" => 150}

      assert {:ok, "huashan-jian/long", 0} =
               SectMaster.inquiry_grant(huashan_player(), %{family: "华山派"}, long)

      heretic = huashan_player(%{skills: %{"huashan-jian" => 10, "force" => 206}})

      assert {:error, "我剑宗以剑术为主，气为次！你的内功修为已入了气宗歧途，再不能修炼剑宗剑术。"} =
               SectMaster.inquiry_grant(heretic, %{family: "华山派"}, long)
    end

    test "风清扬 8 破式走 potential 解锁 handler；丛不弃仅教学不收徒", %{world: world} do
      feng = npc(world, "风清扬", "huashan:luoyan")
      assert feng.meta.teach.family == "华山剑宗"
      assert feng.meta.teach.no_teach == ["dugu-jiujian"]

      for key <- ~w(破剑式 破刀式 破枪式 破鞭式 破索式 破掌式 破箭式 破气式) do
        cfg = inquiry(feng, key)
        assert cfg["kind"] == "sect_master_unlock_perform"
        assert cfg["perform_id"] == "dugu-jiujian/po"
        assert cfg["min_potential"] == 10
        assert is_binary(cfg["learned"])
      end

      assert {:exhausted, "你听了风清扬的教导，颇觉迷茫，看来是潜能不够了。"} =
               SectMaster.unlock_perform(
                 huashan_player(%{skills: %{"dugu-jiujian" => 100}, potential: 9}),
                 inquiry(feng, "破剑式")
               )

      cong = npc(world, "丛不弃", "huashan:shangu")
      assert cong.meta.teach.family == "华山剑宗"
      assert map_size(cong.meta.teach.teach_skills) == 11
      assert is_nil(cong.meta.inquiries)
      assert is_nil(cong.meta.apprentice)
    end

    test "劳德诺 4 门绝招 + 收徒侠义门；岳不群 5 招 + 紫霞秘籍 + 性别收徒门", %{world: world} do
      lao = npc(world, "劳德诺", "huashan:laojun")
      jie = inquiry(lao, "截手式")
      assert jie["perform_id"] == "huashan-jian/jie"
      assert jie["min_gongxian"] == 60
      assert jie["min_shen"] == 500
      assert jie["cost_gongxian"] == 60
      assert lao.meta.apprentice.min_shen == 0
      assert lao.meta.apprentice.min_shen_deny == "我华山派乃名门正派，不收你这种心术不正之徒！"

      assert {:ok, "huashan-jian/jie", 60} =
               SectMaster.inquiry_grant(
                 huashan_player(%{gongxian: 60, shen: 500}),
                 %{family: "华山派"},
                 jie
               )

      yue = npc(world, "岳不群", "huashan:qunxianguan")
      san = inquiry(yue, "华岳三神峰")
      assert san["perform_id"] == "fanliangyi-dao/san"
      assert san["min_max_neili"] == 2000
      assert san["min_gongxian"] == 300
      assert san["min_shen"] == 24_000
      assert san["cost_gongxian"] == 300

      book = inquiry(yue, "紫霞秘籍")
      assert book["kind"] == "give_item"
      assert book["item"] == "clone_lib:zixia_book"
      assert book["min_shen"] == 30_000

      # min_skill_levels 的 UCL 键保留下划线；消费端 GiveItem 双查连字符 skill id。
      assert book["min_skill_levels"] == %{"huashan_xinfa" => 160}
      assert yue.meta.apprentice.gender == "男性"
      assert yue.meta.apprentice.gender_deny == "我不收女徒弟，你还是去找我师妹吧！"

      assert yue.meta.apprentice.min_skills_deny["huashan-jian"] ==
               "你华山剑法还不够熟练，下去多练习练习再来找我吧！"

      assert yue.meta.teach.no_teach_deny["pixie-jian"] ==
               "哈哈！那是林家的家传武功，我怎么可能会呢？"
    end

    test "令狐冲琴谱/冲灵剑法与岳夫人宁氏一剑落位", %{world: world} do
      linghu = npc(world, "令狐冲", "huashan:sgyhole1")
      assert linghu.meta.inquiries["琴谱"]["item"] == "clone_lib:qin"
      assert linghu.meta.inquiries["琴谱"]["count"] == "music_book"
      assert linghu.meta.inquiry_state == %{"music_book" => 1}

      chongling = inquiry(linghu, "冲灵剑法")
      assert chongling["kind"] == "sect_master_teach_skill"
      assert chongling["gate_order"] == "known_first"
      assert chongling["level_source"] == "huashan-jian"
      assert chongling["level_divisor"] == 10
      assert map_size(linghu.meta.teach.no_teach_deny) == 2

      wife = npc(world, "岳夫人", "huashan:jushi")
      ning = inquiry(wife, "宁氏一剑")
      assert ning["perform_id"] == "shunv-jian/ning"
      assert ning["min_gongxian"] == 600
      assert ning["min_shen"] == 30_000
      assert wife.meta.apprentice.gender == "女性"
    end
  end

  describe "绝情谷 UCL 数据回填（Task #745）" do
    test "裘千尺：22 skills / 5 grants / 改姓与仇家门控 / 掌心雷 -950000", %{world: world} do
      chi = npc(world, "裘千尺", "jueqing:undertan")

      assert chi.meta.teach.family == "绝情谷"
      assert map_size(chi.meta.teach.teach_skills) == 22
      assert chi.meta.apprentice.permit_recruit == true
      assert chi.meta.apprentice.reject_master_name == "公孙止"
      assert chi.meta.apprentice.no_min_shen == true
      assert chi.meta.apprentice.max_shen == -60_000
      assert chi.meta.apprentice.min_exp == 400_000
      assert chi.meta.apprentice.rename_surname_from == "公孙"
      assert chi.meta.apprentice.rename_surname_to == "裘"

      assert map_size(chi.meta.inquiries) == 8

      levin = inquiry(chi, "掌心雷")
      assert levin["kind"] == "sect_master_grant"
      assert levin["perform_id"] == "tie-zhang/lei"
      assert levin["max_shen"] == -950_000
      assert levin["cost_gongxian"] == 600

      invisible = inquiry(chi, "无影掌")
      assert String.starts_with?(invisible["msg_one"], "$N点了点头")
      assert invisible["min_levels"] == %{"tie-zhang" => 100, "force" => 160}

      assert is_binary(inquiry(chi, "历练"))
      assert String.contains?(inquiry(chi, "历练"), "GAP #747")
    end

    test "樊一翁：20 skills / 8 grants / shen 上界 0 / LPC 顺序", %{world: world} do
      fan = npc(world, "樊一翁", "jueqing:shanzhuang")

      assert fan.meta.teach.family == "绝情谷"
      assert map_size(fan.meta.teach.teach_skills) == 20
      assert fan.meta.apprentice.max_shen == 0
      assert map_size(fan.meta.inquiries) == 8

      tai = inquiry(fan, "泰山压顶")
      assert tai["perform_id"] == "poshui-zhang/tai"
      assert tai["min_levels"] == %{"poshui-zhang" => 120, "force" => 160}
      assert tai["max_shen"] == -18_000
      assert tai["gate_order"] == "lpc_masterd"

      wan = inquiry(fan, "万念惧灰")
      assert wan["min_levels"]["dodge"] == 80
      assert String.starts_with?(wan["msg_one"], "樊一翁点了点头")
    end

    test "公孙止：23 skills / 8 grants / 2 give_item / 仇家与嫡传门控", %{world: world} do
      zhi = npc(world, "公孙止", "jueqing:zizhuxuan")

      assert zhi.meta.teach.family == "绝情谷"
      assert map_size(zhi.meta.teach.teach_skills) == 23
      assert zhi.meta.apprentice.reject_master_name == "裘千尺"
      assert zhi.meta.apprentice.max_shen == -30_000
      assert zhi.meta.apprentice.min_exp == 300_000
      assert map_size(zhi.meta.inquiries) == 13

      heng = inquiry(zhi, "横空出世")
      assert heng["perform_id"] == "yinyang-ren/heng"
      assert heng["min_levels"] == %{"yinyang-ren" => 180, "dodge" => 180, "force" => 180}
      assert heng["max_shen"] == -100_000

      sword = inquiry(zhi, "黑剑")
      assert sword["kind"] == "give_item"
      assert sword["item"] == "clone_lib:heijian"
      assert sword["master_id"] == "true"
      assert sword["max_shen"] == -46_000
      assert sword["min_skill_levels"] == %{"yinyang_ren" => 150}

      dao = inquiry(zhi, "黄金锯齿刀")
      assert dao["item"] == "clone_lib:juchidao"
      assert dao["max_shen"] == -50_000
      assert dao["min_skill_levels"] == %{"yinyang_ren" => 180}

      assert String.contains?(inquiry(zhi, "锻炼"), "GAP #747")
    end
  end

  describe "武当派 UCL 数据回填（Task #619）" do
    test "莫声谷 2 门绝招：太极初升 + 隔山打牛", %{world: world} do
      mo = npc(world, "莫声谷", "wudang:nanyanfeng")
      assert mo, "莫声谷应随世界加载（wudang:nanyanfeng）"
      assert mo.meta.teach.family == "武当派"

      sheng = inquiry(mo, "太极初升")
      assert sheng["perform_id"] == "wudang-jian/sheng"
      assert sheng["skill"] == "wudang-jian"
      assert sheng["min_gongxian"] == 80
      assert sheng["min_shen"] == 2000
      assert sheng["cost_gongxian"] == 80
      assert sheng["min_max_neili"] == 300
      assert sheng["min_levels"] == %{"force" => 80, "wudang-jian" => 60}
      assert sheng["family_deny"] == "不是我们武当派的人，何出此言？"
      assert sheng["skill_deny"] == "你连武当剑法都没学，还谈什么绝招可言？"
      assert sheng["gongxian_deny"] == "你为我武当派效力还不够，这招我先不忙传你。"
      assert sheng["shen_deny"] == "你行侠仗义的事情做的还很不够，我不能传你绝招！"

      assert sheng["level_deny"] == %{
               "force" => "你的内功的修为不够，练高了再来吧。",
               "wudang-jian" => "你的武当剑法修为太浅，修炼好了再来吧。"
             }

      assert sheng["max_neili_deny"] == "你的内力修为太浅，修炼高了再来吧。"
      assert sheng["maxed"] == "你自己去练习吧。"
      assert sheng["learned"] == "你学会了「太极初升」。"
      assert mo.meta.teach.no_teach_deny["taiji-shengong"] == "要想学习太极神功请向张真人请教。"

      da = inquiry(mo, "隔山打牛")
      assert da["perform_id"] == "zhenshan-zhang/da"
      assert da["skill"] == "zhenshan-zhang"
      assert da["min_gongxian"] == 50
      assert da["min_shen"] == 6000
      assert da["cost_gongxian"] == 50
      assert da["min_max_neili"] == 200
      assert da["min_levels"] == %{"zhenshan-zhang" => 40}
      assert da["family_deny"] == "不是我们武当派的人，何出此言？"
      assert da["skill_deny"] == "你连震山掌都没学，还谈什么绝招可言？"
      assert da["gongxian_deny"] == "你为我武当派效力还不够，这招我先不忙传你。"
      assert da["shen_deny"] == "你行侠仗义的事情做的还很不够，我不能传你绝招！"
      assert da["max_neili_deny"] == "你的内力修为太浅，修炼高了再来吧。"
      assert da["level_deny"] == "你的震山掌修为太浅，修炼好了再来吧。"
      assert da["maxed"] == "能教的我都教了，你自己练习吧。"
      assert da["learned"] == "你学会了「隔山打牛」。"
    end

    test "张翠山 1 门绝招：谁与争锋", %{world: world} do
      shan = npc(world, "张翠山", "wudang:jiejianyan")
      assert shan, "张翠山应随世界加载（wudang:jiejianyan）"
      assert shan.meta.teach.family == "武当派"

      zheng = inquiry(shan, "谁与争锋")
      assert zheng["perform_id"] == "yitian-zhang/zheng"
      assert zheng["skill"] == "yitian-zhang"
      assert zheng["min_gongxian"] == 200
      assert zheng["min_shen"] == 12000
      assert zheng["cost_gongxian"] == 200
      assert zheng["min_max_neili"] == 800
      assert zheng["min_levels"] == %{"yitian-zhang" => 120}
      assert zheng["max_neili_deny"] == "你的内力修为太浅，修炼高了再来吧。"
      assert zheng["family_deny"] == "不是我们武当派的人，何出此言？"
      assert zheng["skill_deny"] == "你连倚天屠龙掌都没学，还谈什么绝招可言？"
      assert zheng["gongxian_deny"] == "你为我武当派效力还不够，这招我先不忙传你。"
      assert zheng["shen_deny"] == "你行侠仗义的事情做的还很不够，我不能传你绝招！"
      assert zheng["level_deny"] == "你的倚天屠龙掌还不到家，要多练练！"
      assert zheng["maxed"] == "你不是已经会了吗？怎么老是纠缠不休。"
      assert zheng["learned"] == "你学会了「谁与争锋」。"
    end

    test "张松溪 1 门绝招：乱环诀", %{world: world} do
      xi = npc(world, "张松溪", "wudang:donglang1")
      assert xi, "张松溪应随世界加载（wudang:donglang1）"
      assert xi.meta.teach.family == "武当派"

      huan = inquiry(xi, "乱环诀")
      assert huan["perform_id"] == "xuanxu-dao/huan"
      assert huan["skill"] == "xuanxu-dao"
      assert huan["min_gongxian"] == 150
      assert huan["min_shen"] == 10000
      assert huan["cost_gongxian"] == 150
      assert huan["min_levels"] == %{"xuanxu-dao" => 100}
      assert huan["family_deny"] == "不是我们武当派的人，何出此言？"
      assert huan["skill_deny"] == "你连玄虚刀法都没学，还谈什么绝招可言？"
      assert huan["gongxian_deny"] == "你为我武当派效力还不够，这招我先不忙传你。"
      assert huan["shen_deny"] == "你行侠仗义的事情做的还很不够，我不能传你绝招！"
      assert huan["level_deny"] == "你的玄虚刀法还不到家，要多练练！"
      assert huan["maxed"] == "我都教给你了，自己好好多练习吧！"
      assert huan["learned"] == "你学会了「乱环决」。"
    end

    test "殷梨亭 1 门绝招：柔月穿空", %{world: world} do
      yin = npc(world, "殷梨亭", "wudang:caolianfang")
      assert yin, "殷梨亭应随世界加载（wudang:caolianfang）"
      assert yin.meta.teach.family == "武当派"

      chuan = inquiry(yin, "柔月穿空")
      assert chuan["perform_id"] == "raozhi-roujian/chuankong"
      assert chuan["skill"] == "raozhi-roujian"
      assert chuan["min_gongxian"] == 250
      assert chuan["min_shen"] == 15000
      assert chuan["cost_gongxian"] == 250
      assert chuan["min_max_neili"] == nil
      assert chuan["min_levels"] == %{"force" => 150, "raozhi-roujian" => 100}
      assert chuan["family_deny"] == "不是我们武当派的人，何出此言？"
      assert chuan["skill_deny"] == "你连绕指柔剑都没学，还谈什么绝招可言？"
      assert chuan["gongxian_deny"] == "你为我武当派效力还不够，这招我先不忙传你。"
      assert chuan["shen_deny"] == "你行侠仗义的事情做的还很不够，我不能传你绝招！"

      assert chuan["level_deny"] == %{
               "force" => "你的内功的修为不够，练高了再来吧。",
               "raozhi-roujian" => "你的绕指柔剑还不到家，要多练练！"
             }

      assert chuan["maxed"] == "自己好好多练习吧！"
      assert chuan["learned"] == "你学会了「柔月穿空」。"
    end

    test "俞莲舟 1 门绝招：绝户神抓", %{world: world} do
      yu = npc(world, "俞莲舟", "wudang:houyuan")
      assert yu, "俞莲舟应随世界加载（wudang:houyuan）"
      assert yu.meta.teach.family == "武当派"

      juehu = inquiry(yu, "绝户神抓")
      assert juehu["perform_id"] == "huzhua-shou/juehu"
      assert juehu["skill"] == "huzhua-shou"
      assert juehu["min_gongxian"] == 400
      assert juehu["min_shen"] == 100_000
      assert juehu["cost_gongxian"] == 400
      assert juehu["min_levels"] == %{"force" => 180, "huzhua-shou" => 120}
      assert juehu["family_deny"] == "不是我们武当派的人，何出此言？"
      assert juehu["skill_deny"] == "你连虎爪绝户手都没学，还谈什么绝招可言？"
      assert juehu["gongxian_deny"] == "你为我武当派效力还不够，这招我先不忙传你。"
      assert juehu["shen_deny"] == "这一招太过阴恨，如果被你用去我恐怕不放心！"

      assert juehu["level_deny"] == %{
               "force" => "你的内功的修为不够，练高了再来吧。",
               "huzhua-shou" => "你的虎爪绝户手还不到家，还是自己先下去多多练习吧。"
             }

      assert juehu["maxed"] == "这一招你不是已经会了吗？"
      assert juehu["learned"] == "你学会了「绝户神抓」。"
    end

    test "俞岱岩：teach + no_teach map，无 inquiry", %{world: world} do
      yan = npc(world, "俞岱岩", "wudang:gaotai")
      assert yan, "俞岱岩应随世界加载（wudang:gaotai）"
      assert yan.meta.teach.family == "武当派"
      assert is_nil(yan.meta.inquiries)

      assert Enum.sort(yan.meta.teach.no_teach) ==
               ["taiji-jian", "taiji-quan", "taiji-shengong"]

      assert yan.meta.teach.no_teach_deny["taiji-shengong"] == "要想学习太极神功请向张真人请教。"
      assert yan.meta.teach.no_teach_deny["taiji-jian"] == "太极剑必须张真人亲传。"
      assert yan.meta.teach.no_teach_deny["taiji-quan"] == "太极拳必须张真人亲传。"
    end

    test "张三丰：武当九阳功不可无条件传授（任务链门控待移植 GAP #789）", %{world: world} do
      zhang = npc(world, "张三丰", "wudang:xiaoyuan")
      assert zhang, "张三丰应随世界加载（wudang:xiaoyuan）"
      assert zhang.meta.teach.family == "武当派"

      # LPC zhang.c ask_jiuyang 需昆仑+少林双任务标记；未实现前绝不直接放入 teach_skills。
      assert is_nil(Map.get(zhang.meta.teach.teach_skills, "wudang-jiuyang"))
      assert "wudang-jiuyang" in zhang.meta.teach.no_teach
    end
  end

  describe "武当派 门控联验（Task #619）" do
    defp wudang_disciple(overrides \\ %{}) do
      disciple(%{
        skills: %{
          "wudang-jian" => 60,
          "force" => 80,
          "zhenshan-zhang" => 40,
          "yitian-zhang" => 120,
          "xuanxu-dao" => 100,
          "raozhi-roujian" => 100,
          "huzhua-shou" => 120
        },
        gongxian: 500,
        shen: 20000,
        max_neili: 1000,
        family: "武当派"
      })
      |> Map.merge(overrides)
    end

    test "武当弟子全达标 → 学会「太极初升」并扣 80 贡献", %{world: world} do
      cfg = inquiry(npc(world, "莫声谷", "wudang:nanyanfeng"), "太极初升")
      player = wudang_disciple(%{gongxian: 80, shen: 2000, max_neili: 300})

      assert {:ok, "wudang-jian/sheng", 80} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
    end

    test "非武当派 → family_deny", %{world: world} do
      cfg = inquiry(npc(world, "莫声谷", "wudang:nanyanfeng"), "太极初升")
      player = wudang_disciple(%{family: "少林派"})

      assert {:error, "不是我们武当派的人，何出此言？"} = SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
    end

    test "贡献不足（太极初升 80）→ gongxian_deny", %{world: world} do
      cfg = inquiry(npc(world, "莫声谷", "wudang:nanyanfeng"), "太极初升")
      player = wudang_disciple(%{gongxian: 79, shen: 2000, max_neili: 300})

      assert {:error, "你为我武当派效力还不够，这招我先不忙传你。"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
    end

    test "杀气不足（太极初升 2000）→ shen_deny", %{world: world} do
      cfg = inquiry(npc(world, "莫声谷", "wudang:nanyanfeng"), "太极初升")
      player = wudang_disciple(%{gongxian: 80, shen: 1999, max_neili: 300})

      assert {:error, "你行侠仗义的事情做的还很不够，我不能传你绝招！"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
    end

    test "等级不足（隔山打牛 zhenshan-zhang 40）→ level_deny", %{world: world} do
      cfg = inquiry(npc(world, "莫声谷", "wudang:nanyanfeng"), "隔山打牛")

      player =
        wudang_disciple(%{
          skills: %{
            "zhenshan-zhang" => 39,
            "force" => 80,
            "wudang-jian" => 60,
            "yitian-zhang" => 120,
            "xuanxu-dao" => 100,
            "raozhi-roujian" => 100,
            "huzhua-shou" => 120
          },
          gongxian: 50,
          shen: 6000,
          max_neili: 200
        })

      assert {:error, "你的震山掌修为太浅，修炼好了再来吧。"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
    end

    test "内力不足（谁与争锋 800）→ max_neili_deny", %{world: world} do
      cfg = inquiry(npc(world, "张翠山", "wudang:jiejianyan"), "谁与争锋")
      player = wudang_disciple(%{gongxian: 200, shen: 12000, max_neili: 799})

      assert {:error, "你的内力修为太浅，修炼高了再来吧。"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)

      assert {:ok, "yitian-zhang/zheng", 200} =
               SectMaster.inquiry_grant(%{player | max_neili: 800}, %{family: "武当派"}, cfg)
    end

    test "绝户神抓：shen < 100000 → shen_deny；达标过门", %{world: world} do
      cfg = inquiry(npc(world, "俞莲舟", "wudang:houyuan"), "绝户神抓")

      yu_skills = %{"force" => 180, "huzhua-shou" => 120}

      too_good =
        wudang_disciple(%{skills: yu_skills, gongxian: 400, shen: 99_999, max_neili: 1000})

      assert {:error, "这一招太过阴恨，如果被你用去我恐怕不放心！"} =
               SectMaster.inquiry_grant(too_good, %{family: "武当派"}, cfg)

      evil = wudang_disciple(%{skills: yu_skills, gongxian: 400, shen: 100_000, max_neili: 1000})

      assert {:ok, "huzhua-shou/juehu", 400} =
               SectMaster.inquiry_grant(evil, %{family: "武当派"}, cfg)
    end

    test "太极初升：force 不足命中内功文案、剑法不足命中剑法文案", %{world: world} do
      cfg = inquiry(npc(world, "莫声谷", "wudang:nanyanfeng"), "太极初升")

      weak_force =
        wudang_disciple(%{
          skills: %{"force" => 79, "wudang-jian" => 60, "zhenshan-zhang" => 40},
          gongxian: 80,
          shen: 2000,
          max_neili: 300
        })

      assert {:error, "你的内功的修为不够，练高了再来吧。"} =
               SectMaster.inquiry_grant(weak_force, %{family: "武当派"}, cfg)

      weak_sword =
        wudang_disciple(%{
          skills: %{"force" => 80, "wudang-jian" => 59, "zhenshan-zhang" => 40},
          gongxian: 80,
          shen: 2000,
          max_neili: 300
        })

      assert {:error, "你的武当剑法修为太浅，修炼好了再来吧。"} =
               SectMaster.inquiry_grant(weak_sword, %{family: "武当派"}, cfg)
    end
  end

  describe "昆仑派 UCL 数据回填（Task #750-#755）" do
    defp kunlun_npc(world, name) do
      Enum.find(world.characters, fn c ->
        c.name == name and Map.get(Map.get(c.meta, :teach) || %{}, :family) == "昆仑派"
      end)
    end

    test "8 NPC 的 teach/apprentice 全部落位，技能上限与 LPC 一致", %{world: world} do
      expected = [
        {"班淑娴", 20},
        {"高则成", 15},
        {"何太冲", 20},
        {"何足道", 26},
        {"蒋涛", 15},
        {"卫四娘", 17},
        {"西华子", 17},
        {"詹春", 15}
      ]

      for {name, skill_count} <- expected do
        npc = kunlun_npc(world, name)
        assert npc, "#{name} 应随世界加载"
        assert npc.meta.teach.family == "昆仑派"
        assert map_size(npc.meta.teach.teach_skills) == skill_count
        assert npc.meta.apprentice.family == "昆仑派"
        assert npc.meta.apprentice.permit_recruit == true
        assert npc.meta.apprentice.betray_sect_deny == "亏你还有脸回我昆仑山？给我滚开！"
        assert npc.meta.apprentice.betray_times_deny == "阁下不忠不信，我最痛恨你这种人了。"

        assert npc.meta.apprentice.other_family_deny ==
                 "阁下既有了名师指点，还来我们昆仑派做什么？"
      end
    end

    test "班淑娴 2 招 / 何太冲 5 招：level_order 与逐条文案落位", %{world: world} do
      ban = kunlun_npc(world, "班淑娴")
      assert map_size(ban.meta.inquiries) == 9

      sun = inquiry(ban, "损筋诀")
      assert sun["kind"] == "sect_master_grant"
      assert sun["perform_id"] == "sanyin-shou/sun"
      assert sun["gate_order"] == "lpc_kunlun"
      assert sun["level_order"] == ["force", "sanyin-shou"]
      assert sun["min_levels"] == %{"force" => 200, "sanyin-shou" => 140}
      assert sun["cost_gongxian"] == 400
      assert sun["improve_skills"] == ["hand", "sanyin-shou", "martial-cognize"]

      wu = inquiry(ban, "无声无色")
      assert wu["level_order"] == ["force", "dodge", "dex", "zhengliangyi-jian"]
      assert wu["min_levels"]["dex"] == 45

      he = kunlun_npc(world, "何太冲")
      assert map_size(he.meta.inquiries) == 12

      sui = inquiry(he, "玉碎昆冈")
      assert sui["perform_id"] == "zhengliangyi-jian/sui"
      assert sui["level_order"] == ["force", "max-neili", "zhengliangyi-jian"]
      assert sui["min_levels"]["max-neili"] == 3000
      assert sui["level_deny"]["max-neili"] == "你的内力修为不足，学不了这一招。"

      fan = inquiry(he, "域外梵音")
      assert fan["level_order"] == ["force", "tanqin-jifa", "kunlun-jian"]
      assert fan["level_deny"]["tanqin-jifa"] == "你的弹琴技法尚且不够熟练, 学不了这一招！"
      assert String.contains?(fan["msg_one"], "前所谓闻")

      assert String.contains?(inquiry(he, "铁琴剑"), "GAP #756")
      assert String.contains?(inquiry(he, "迅雷剑经"), "GAP #756")
    end

    test "何足道 4 招：requires_perform / 五技能提升 / 两极剑缺口标记", %{world: world} do
      he = kunlun_npc(world, "何足道")
      assert map_size(he.meta.teach.teach_skills) == 26
      assert he.meta.apprentice.hard_min_int == 38
      assert String.contains?(he.meta.apprentice.min_shen_deny, "%respect%")

      ni = inquiry(he, "逆转乾坤")
      assert ni["requires_perform"] == "qiankun-jian/qian"
      assert ni["requires_perform_deny"] == "要学此招，必须先通晓「乾坤劲」的奥秘。"

      assert ni["improve_skills"] == [
               "force",
               "liangyi-shengong",
               "sword",
               "qiankun-jian",
               "martial-cognize"
             ]

      assert String.contains?(inquiry(he, "两极剑"), "GAP #756")
    end

    test "真实 UCL 配置：max-neili 在最终技能等级之前判定", %{world: world} do
      he = kunlun_npc(world, "何太冲")
      config = inquiry(he, "玉碎昆冈")

      player = %{
        family: "昆仑派",
        gongxian: 800,
        max_neili: 2999,
        skills: %{"force" => 250, "zhengliangyi-jian" => 180},
        performs: MapSet.new()
      }

      assert {:error, "你的内力修为不足，学不了这一招。\n"} =
               SectMaster.inquiry_grant(player, %{family: "昆仑派"}, config)
    end

    test "真实 UCL 配置：逆转乾坤必须先会乾坤劲", %{world: world} do
      he = kunlun_npc(world, "何足道")
      config = inquiry(he, "逆转乾坤")

      player = %{
        family: "昆仑派",
        gongxian: 1800,
        skills: %{"force" => 300, "qiankun-jian" => 180},
        performs: MapSet.new()
      }

      assert {:error, "要学此招，必须先通晓「乾坤劲」的奥秘。\n"} =
               SectMaster.inquiry_grant(player, %{family: "昆仑派"}, config)

      ready = %{player | performs: MapSet.new(["qiankun-jian/qian"])}

      assert {:ok, "qiankun-jian/ni", 1800} =
               SectMaster.inquiry_grant(ready, %{family: "昆仑派"}, config)
    end

    test "卫四娘/西华子的 no_teach 两条逐字落位", %{world: world} do
      for name <- ["卫四娘", "西华子"] do
        npc = kunlun_npc(world, name)

        assert npc.meta.teach.no_teach_deny["liangyi-shengong"] ==
                 "两仪神功需得掌门人亲自传授。"

        assert npc.meta.teach.no_teach_deny["zhengliangyi-jian"] ==
                 "正两仪剑法乃本门神功，需要掌门人亲自传授。"
      end
    end
  end

  describe "少林派 UCL 数据回填（Task #619）" do
    test "无名老僧 3 门绝招：万佛朝宗 / 如影随形 / 避云遮日，door 控字段与 LPC ask_skill1/accept_ask 一致", %{world: world} do
      npc = npc(world, "无名老僧", "shaolin:cjlou")
      assert npc, "无名老僧应随世界加载（shaolin:cjlou）"

      # 万佛朝宗：ask_skill1，perform_id rulai-zhang/zong
      zong = inquiry(npc, "万佛朝宗")
      assert zong["kind"] == "sect_master_grant"
      assert zong["perform_id"] == "rulai-zhang/zong"
      assert zong["skill"] == "rulai-zhang"
      assert zong["min_gongxian"] == 800
      assert zong["min_shen"] == 150_000
      assert zong["cost_gongxian"] == 800
      assert zong["min_levels"] == %{"force" => 350, "rulai-zhang" => 220}
      assert zong["family"] == "少林派"
      assert zong["family_deny"] == "老衲与阁下素无渊源，不知阁下这话从何而来？"
      assert zong["skill_deny"] == "你连千手如来掌都没学，还谈什么绝招可言？"
      assert zong["gongxian_deny"] == "嗯，你在少林派没什么作为，这招我不传你。"
      assert zong["shen_deny"] == "你侠义正事做得不够，这招我不能传你。"

      assert zong["level_deny"] == %{
               "force" => "你的内功火候不足，用不了这一招！",
               "rulai-zhang" => "你千手如来掌尚未修炼得精深，难以运用此招。"
             }

      assert zong["maxed"] == "你已经学会了此招，还和老衲开这种玩笑。"
      assert zong["learned"] == "你学会了「万佛朝宗」。"

      # 如影随形：accept_ask，perform_id ruying-suixingtui/ruying
      ruying = inquiry(npc, "如影随形")
      assert ruying["kind"] == "sect_master_grant"
      assert ruying["perform_id"] == "ruying-suixingtui/ruying"
      assert ruying["skill"] == "ruying-suixingtui"
      assert ruying["min_gongxian"] == 800
      assert ruying["min_shen"] == 30_000
      assert ruying["cost_gongxian"] == 800
      assert ruying["min_levels"] == %{"ruying-suixingtui" => 160, "force" => 250}

      # 避云遮日：accept_ask，perform_id jiasha-fumogong/zhe
      zhe = inquiry(npc, "避云遮日")
      assert zhe["kind"] == "sect_master_grant"
      assert zhe["perform_id"] == "jiasha-fumogong/zhe"
      assert zhe["skill"] == "jiasha-fumogong"
      assert zhe["min_gongxian"] == 1000
      assert zhe["min_shen"] == 70_000
      assert zhe["cost_gongxian"] == 1000
      assert zhe["min_levels"] == %{"jiasha-fumogong" => 180, "force" => 300}
    end

    defp shaolin_disciple(overrides \\ %{}) do
      disciple(%{
        skills: %{"rulai-zhang" => 220, "force" => 350},
        gongxian: 800,
        shen: 150_000,
        max_neili: 0,
        family: "少林派"
      })
      |> Map.merge(overrides)
    end

    test "少林弟子全达标 → 学会「万佛朝宗」并扣 800 贡献", %{world: world} do
      cfg = inquiry(npc(world, "无名老僧", "shaolin:cjlou"), "万佛朝宗")

      assert {:ok, "rulai-zhang/zong", 800} =
               SectMaster.inquiry_grant(
                 shaolin_disciple(),
                 %{family: "少林派"},
                 cfg
               )
    end

    test "非少林派 → family_deny", %{world: world} do
      cfg = inquiry(npc(world, "无名老僧", "shaolin:cjlou"), "万佛朝宗")

      outsider = shaolin_disciple(%{family: "武当派"})

      assert {:error, "老衲与阁下素无渊源，不知阁下这话从何而来？"} =
               SectMaster.inquiry_grant(
                 outsider,
                 %{family: "少林派"},
                 cfg
               )
    end

    test "杀气不足（shen < 150000）→ shen_deny", %{world: world} do
      cfg = inquiry(npc(world, "无名老僧", "shaolin:cjlou"), "万佛朝宗")

      low_shen = shaolin_disciple(%{shen: 149_999})

      assert {:error, "你侠义正事做得不够，这招我不能传你。"} =
               SectMaster.inquiry_grant(
                 low_shen,
                 %{family: "少林派"},
                 cfg
               )
    end

    test "贡献不足（gongxian < 800）→ gongxian_deny", %{world: world} do
      cfg = inquiry(npc(world, "无名老僧", "shaolin:cjlou"), "万佛朝宗")

      low_gongxian = shaolin_disciple(%{gongxian: 799})

      assert {:error, "嗯，你在少林派没什么作为，这招我不传你。"} =
               SectMaster.inquiry_grant(
                 low_gongxian,
                 %{family: "少林派"},
                 cfg
               )
    end

    test "内功等级不足（force < 350）→ level_deny force", %{world: world} do
      cfg = inquiry(npc(world, "无名老僧", "shaolin:cjlou"), "万佛朝宗")

      low_force = shaolin_disciple(%{skills: %{"rulai-zhang" => 220, "force" => 349}})

      assert {:error, "你的内功火候不足，用不了这一招！"} =
               SectMaster.inquiry_grant(
                 low_force,
                 %{family: "少林派"},
                 cfg
               )
    end

    test "千手如来掌等级不足（rulai-zhang < 220）→ level_deny rulai-zhang", %{world: world} do
      cfg = inquiry(npc(world, "无名老僧", "shaolin:cjlou"), "万佛朝宗")

      low_skill = shaolin_disciple(%{skills: %{"rulai-zhang" => 219, "force" => 350}})

      assert {:error, "你千手如来掌尚未修炼得精深，难以运用此招。"} =
               SectMaster.inquiry_grant(
                 low_skill,
                 %{family: "少林派"},
                 cfg
               )
    end
  end

  describe "血刀派 UCL 数据回填（Task #619）" do
    @xuedao_grants [
      {"浴血重生", "xuedao-dafa/resurrect", "xuedao-dafa", 500, -60_000, 1000},
      {"金刚印", "dashou-yin/yin", "dashou-yin", 200, -15_000, 1000},
      {"修罗降世", "yujiamu-quan/jiang", "yujiamu-quan", 300, -18_000, 1200},
      {"若悲", "mingwang-jian/ruo", "mingwang-jian", 100, -10_000, 1200},
      {"降魔", "mingwang-jian/xiang", "mingwang-jian", 400, -15_000, 1600},
      {"无影神刀", "xuedao-dafa/ying", "xuedao-dafa", 300, -60_000, 1500},
      {"赤炼神刀", "xuedao-dafa/chi", "xuedao-dafa", 800, -70_000, 2400},
      {"祭血神刀", "xuedao-dafa/xue", "xuedao-dafa", 1000, -80_000, 2400},
      {"噬血穹苍", "xuedao-dafa/shi", "xuedao-dafa", 2000, -100_000, 2600}
    ]

    test "血刀老祖 9 门绝招全部落库且保留 LPC 文案", %{world: world} do
      laozu = npc(world, "血刀老祖", "xuedao:shandong3")
      assert laozu, "血刀老祖应随世界加载（xuedao:shandong3）"
      assert laozu.meta.teach.family == "血刀门"

      Enum.each(@xuedao_grants, fn {key, perform_id, skill, gongxian, max_shen, neili} ->
        cfg = inquiry(laozu, key)
        assert cfg["kind"] == "sect_master_grant", "#{key} 应为 sect_master_grant"
        assert cfg["perform_id"] == perform_id
        assert cfg["skill"] == skill
        assert cfg["min_gongxian"] == gongxian
        assert cfg["cost_gongxian"] == gongxian
        assert cfg["max_shen"] == max_shen
        assert cfg["min_max_neili"] == neili
        assert cfg["max_shen_deny"] == "你这人是怎么做的？连杀人都不会了？"
        assert cfg["maxed"] == "自己下去练，啰嗦什么！"
        assert cfg["family_deny"] == "你是什么人？我看你怎么不象是我血刀门的弟子呢？"
        assert String.contains?(cfg["learned"], key)
      end)

      assert length(@xuedao_grants) == 9
    end

    test "血刀老祖 未回填的血刀/血刀经/密道 明确标记为 GAP", %{world: world} do
      laozu = npc(world, "血刀老祖", "xuedao:shandong3")
      assert inquiry(laozu, "密道") =~ "GAP #792"
      assert inquiry(laozu, "血刀") =~ "GAP #793"
      assert inquiry(laozu, "血刀经") =~ "GAP #793"
      assert inquiry(laozu, "冰河开封") == "这一招你去让胜谛教你好了。"
    end

    test "浴血重生：shen 上界 -60000（正神被拒，够邪通过）", %{world: world} do
      cfg = inquiry(npc(world, "血刀老祖", "xuedao:shandong3"), "浴血重生")
      base = %{skills: %{"xuedao-dafa" => 120}, gongxian: 500, max_neili: 1000}

      good = disciple(Map.merge(base, %{shen: -59_999, family: "血刀门"}))
      assert {:error, "你这人是怎么做的？连杀人都不会了？"} = SectMaster.inquiry_grant(good, %{family: "血刀门"}, cfg)

      evil = disciple(Map.merge(base, %{shen: -60_000, family: "血刀门"}))

      assert {:ok, "xuedao-dafa/resurrect", 500} =
               SectMaster.inquiry_grant(evil, %{family: "血刀门"}, cfg)
    end

    test "金刚印：force 与大手印逐技能拒绝文案", %{world: world} do
      cfg = inquiry(npc(world, "血刀老祖", "xuedao:shandong3"), "金刚印")
      base = %{gongxian: 200, shen: -15_000, max_neili: 1000, family: "血刀门"}

      weak_force = disciple(Map.merge(base, %{skills: %{"dashou-yin" => 100, "force" => 139}}))

      assert {:error, "你的内功修为实在太差，修炼高了再来找老夫吧。"} =
               SectMaster.inquiry_grant(weak_force, %{family: "血刀门"}, cfg)

      weak_skill = disciple(Map.merge(base, %{skills: %{"dashou-yin" => 99, "force" => 140}}))

      assert {:error, "等你把大手印练熟了再来找老夫。"} =
               SectMaster.inquiry_grant(weak_skill, %{family: "血刀门"}, cfg)
    end
  end

  describe "大轮寺（雪山派）UCL 数据回填（Task #619）" do
    @xueshan_grants [
      {"达尔巴", "xueshan:cangjingge", "轰雷万钧", "dali-chu/hong", 100, -3000},
      {"达尔巴", "xueshan:cangjingge", "镇魂舞", "xiangmo-chu/zhen", 200, -6000},
      {"霍都", "xueshan:tiantai", "破元通虚", "poxu-daxuefa/tong", 400, -10_000},
      {"金轮法王", "xueshan:neidian", "金刚印", "dashou-yin/yin", 200, -15_000},
      {"金轮法王", "xueshan:neidian", "修罗降世", "yujiamu-quan/jiang", 300, -18_000},
      {"金轮法王", "xueshan:neidian", "若悲", "mingwang-jian/ruo", 100, -10_000},
      {"金轮法王", "xueshan:neidian", "降魔", "mingwang-jian/xiang", 400, -15_000},
      {"金轮法王", "xueshan:neidian", "破立势", "riyue-lun/po", 800, -50_000},
      {"金轮法王", "xueshan:neidian", "圆满势", "riyue-lun/yuan", 800, -50_000},
      {"金轮法王", "xueshan:neidian", "五轮连转", "riyue-lun/lian", 2000, -80_000},
      {"金轮法王", "xueshan:neidian", "龙吞势", "longxiang-gong/tun", 1800, -80_000},
      {"金轮法王", "xueshan:neidian", "象跌势", "longxiang-gong/die", 2200, -120_000},
      {"金轮法王", "xueshan:neidian", "般若极", "longxiang-gong/ji", 2500, -160_000}
    ]

    test "达而巴/霍都/金轮法王 13 门绝招全部落库", %{world: world} do
      Enum.each(@xueshan_grants, fn {name, room, key, perform_id, gongxian, max_shen} ->
        cfg = inquiry(npc(world, name, room), key)
        assert cfg["kind"] == "sect_master_grant", "#{name} #{key} 应为 grant"
        assert cfg["perform_id"] == perform_id
        assert cfg["min_gongxian"] == gongxian
        assert cfg["cost_gongxian"] == gongxian
        assert cfg["max_shen"] == max_shen
        assert cfg["family"] == "大轮寺"
        assert String.contains?(cfg["learned"], key)
      end)

      assert length(@xueshan_grants) == 13
      assert inquiry(npc(world, "金轮法王", "xueshan:neidian"), "密道") =~ "GAP #796"
      assert inquiry(npc(world, "金轮法王", "xueshan:neidian"), "日月金轮") =~ "GAP #797"
    end

    test "金轮法王 破立势：龙象/内功/技能等级顺序与文案", %{world: world} do
      cfg = inquiry(npc(world, "金轮法王", "xueshan:neidian"), "破立势")

      base = %{
        gongxian: 800,
        shen: -50_000,
        max_neili: 1500,
        family: "大轮寺",
        skills: %{"riyue-lun" => 120, "force" => 180}
      }

      weak_lx = disciple(Map.put(base, :skills, Map.put(base.skills, "longxiang-gong", 29)))

      assert {:error, "你的龙象般若功修为不足，还学不了这一招。"} =
               SectMaster.inquiry_grant(weak_lx, %{family: "大轮寺"}, cfg)

      ok = disciple(Map.put(base, :skills, Map.put(base.skills, "longxiang-gong", 30)))
      assert {:ok, "riyue-lun/po", 800} = SectMaster.inquiry_grant(ok, %{family: "大轮寺"}, cfg)
    end

    test "达尔巴 镇魂舞：心软（shen 上界）拒绝", %{world: world} do
      cfg = inquiry(npc(world, "达尔巴", "xueshan:cangjingge"), "镇魂舞")

      player =
        disciple(%{
          skills: %{"xiangmo-chu" => 100, "force" => 150},
          gongxian: 200,
          shen: -5999,
          max_neili: 1500,
          family: "大轮寺"
        })

      assert {:error, "你为人太过心软，这招暂时还不能传你。"} =
               SectMaster.inquiry_grant(player, %{family: "大轮寺"}, cfg)
    end
  end

  describe "侠客岛 UCL 数据回填（Task #619）" do
    test "龙岛主/木岛主 离岛为 exp 门控传送服务（back/离岛 同配置）", %{world: world} do
      cases = [
        {"龙岛主", "xiakedao:shiroom24", "{npc}冷冷的看了一会儿{name}，才道：“你没长腿？”"},
        {"木岛主", "xiakedao:shiroom24", "{npc}皱皱眉头，对{name}道：“你不自己走么？”"}
      ]

      Enum.each(cases, fn {name, room, deny_vision} ->
        npc = npc(world, name, room)
        assert npc, "#{name} 应随世界加载（#{room}）"

        for key <- ["back", "离岛"] do
          cfg = inquiry(npc, key)
          assert cfg["kind"] == "teleport_service", "#{name} #{key}"
          assert cfg["target_room"] == "xiakedao:haitan"
          assert cfg["max_exp"] == 100_000
          assert cfg["max_exp_vision"] == deny_vision
        end

        assert inquiry(npc, "腊八粥") =~ "断肠独骨腐心草"
      end)
    end

    test "石破天 deny_all apprentice 与已回填文本问询落库", %{world: world} do
      shi = Enum.find(world.characters, &(&1.name == "石破天"))
      assert shi
      assert shi.meta.apprentice.deny_all == true
      assert shi.meta.apprentice.deny_msg == "石破天说道：那不成，那不成。我自己都还没学好呢。"

      assert inquiry(shi, "太玄功") == "我…我不知道，这个你别问我。"
      assert inquiry(shi, "石中玉") == "他是我的兄弟，他现在在摩天崖。"
      assert length(Map.keys(shi.meta.inquiries)) == 8
    end

    test "赏善罚恶令与黄衣使者雇助服务明确标记 GAP", %{world: world} do
      zhang = npc(world, "张三", "xiakedao:xkroad6")
      assert inquiry(zhang, "赏善罚恶令") =~ "GAP #800"

      renter = npc(world, "黄衣使者", "xiakedao:haigang")
      assert inquiry(renter, "rent") =~ "GAP #801"
      assert inquiry(renter, "同门") =~ "GAP #801"
      assert inquiry(renter, "师兄") =~ "GAP #801"
    end
  end

  describe "逍遥派 UCL 数据回填（Task #804）" do
    defp xy(world, name) do
      npc = Enum.find(world.characters, &(&1.name == name))
      assert npc, "#{name} 应随世界加载"
      npc
    end

    @xiaoyao_names [
      "范百龄",
      "冯阿三",
      "苟读",
      "康广陵",
      "石清露",
      "苏星河",
      "吴领军",
      "无崖子",
      "薛慕华"
    ]

    test "九名逍遥 NPC 全部带 teach 数据与收徒门控", %{world: world} do
      for name <- @xiaoyao_names do
        npc = xy(world, name)
        assert npc.meta.teach.family == "逍遥派", "#{name} teach.family"
        assert map_size(npc.meta.teach.teach_skills) > 0, "#{name} teach_skills"
        assert npc.meta.apprentice.family == "逍遥派", "#{name} apprentice.family"
        assert npc.meta.apprentice.permit_recruit == true, "#{name} permit_recruit"
        assert npc.meta.apprentice.min_per == 28, "#{name} min_per"
      end
    end

    test "苏星河 no_teach 为逐技能 map，两招不得出现在 teach_skills", %{world: world} do
      su = xy(world, "苏星河")

      assert su.meta.teach.no_teach_deny["zhemei-shou"] ==
               "逍遥折梅手乃本门神功，只能由掌门人传授。"

      assert su.meta.teach.no_teach_deny["liuyang-zhang"] ==
               "这天山六阳掌向来只能由逍遥派掌门传功，我不便教授。"

      refute Map.has_key?(su.meta.teach.teach_skills, "zhemei-shou")
      refute Map.has_key?(su.meta.teach.teach_skills, "liuyang-zhang")
    end

    @xiaoyao_grants [
      {"苏星河", "捕风捉影", "qingyun-shou/zhuo", 50, %{"force" => 100, "qingyun-shou" => 50}},
      {"苏星河", "攀阳邀月", "panyang-zhang/pan", 100, %{"force" => 100, "panyang-zhang" => 60}},
      {"苏星河", "如意六刀", "ruyi-dao/ruyi", 200, %{"force" => 150, "ruyi-dao" => 100}},
      {"无崖子", "流月剑诀", "liuyue-jian/liu", 400, %{"force" => 180, "liuyue-jian" => 120}},
      {"无崖子", "天升剑诀", "liuyue-jian/sheng", 500, %{"force" => 200, "liuyue-jian" => 140}},
      {"无崖子", "洛神凌波", "lingbo-weibu/ling", 600, %{"force" => 180, "lingbo-weibu" => 120}},
      {"无崖子", "生死符", "liuyang-zhang/zhong", 600, %{"force" => 200, "liuyang-zhang" => 150}},
      {"无崖子", "寰阳式", "liuyang-zhang/huan", 900, %{"force" => 200, "liuyang-zhang" => 130}},
      {"无崖子", "折梅式", "zhemei-shou/zhe", 400, %{"force" => 120, "zhemei-shou" => 80}},
      {"无崖子", "海渊式", "zhemei-shou/hai", 900, %{"force" => 200, "zhemei-shou" => 130}},
      {"无崖子", "化妖功", "zhemei-shou/hua", 2500, %{"zhemei-shou" => 220, "max-neili" => 3500}}
    ]

    test "十一条 sect_master_grant 的门控字段与 LPC 一致", %{world: world} do
      for {name, key, perform_id, gongxian, levels} <- @xiaoyao_grants do
        cfg = inquiry(xy(world, name), key)
        assert cfg["kind"] == "sect_master_grant", "#{name}/#{key}"
        assert cfg["perform_id"] == perform_id, "#{name}/#{key}"
        assert cfg["min_gongxian"] == gongxian, "#{name}/#{key}"
        assert cfg["cost_gongxian"] == gongxian, "#{name}/#{key}"
        assert cfg["min_levels"] == levels, "#{name}/#{key}"
      end
    end

    test "苏星河逐条 level_order：内功不足先于招式火候不足", %{world: world} do
      su = xy(world, "苏星河")
      cfg = inquiry(su, "捕风捉影")
      player = disciple(%{family: "逍遥派", gongxian: 50, skills: %{"qingyun-shou" => 50}})

      assert {:error, "你的内功火候不足，学不成这招。\n"} = SectMaster.inquiry_grant(player, su, cfg)

      ready_force = %{player | skills: %{"force" => 100, "qingyun-shou" => 20}}
      assert {:error, "你的青云手火候未到，还得多练习练习。\n"} = SectMaster.inquiry_grant(ready_force, su, cfg)
    end

    test "化妖功 max_neili 伪键与 LPC 三连提升次数保留", %{world: world} do
      wu = xy(world, "无崖子")
      cfg = inquiry(wu, "化妖功")

      assert cfg["level_order"] == ["zhemei-shou", "max-neili"]

      assert cfg["improve_skills"] == [
               "hand",
               "hand",
               "hand",
               "zhemei-shou",
               "zhemei-shou",
               "zhemei-shou",
               "force",
               "force",
               "force",
               "martial-cognize"
             ]

      player =
        disciple(%{
          family: "逍遥派",
          gongxian: 2500,
          max_neili: 3400,
          skills: %{"zhemei-shou" => 220}
        })

      assert {:error, "你的内力修为不够，强运这招会扰乱自身的真元。\n"} = SectMaster.inquiry_grant(player, wu, cfg)
    end

    test "物品授予类问询明确标记 GAP #805/#806/#807", %{world: world} do
      assert inquiry(xy(world, "冯阿三"), "铁八卦") =~ "GAP #805"
      assert inquiry(xy(world, "冯阿三"), "布阵箱") =~ "GAP #805"
      assert inquiry(xy(world, "苟读"), "论语") =~ "GAP #806"
      assert inquiry(xy(world, "无崖子"), "逍遥神仙环") =~ "GAP #807"
      assert inquiry(xy(world, "无崖子"), "掌门人信物") =~ "GAP #807"
    end
  end

  describe "星宿派 UCL 数据回填（Task #811）" do
    defp xx(world, name) do
      npc = Enum.find(world.characters, &(&1.name == name))
      assert npc, "#{name} 应随世界加载"
      npc
    end

    @xingxiu_names ["阿紫", "出尘子", "丁春秋", "星宿弟子", "狮吼子", "天狼子", "摘星子"]

    test "七名星宿 NPC 全部带 teach 与 apprentice 数据", %{world: world} do
      for name <- @xingxiu_names do
        npc = xx(world, name)
        assert npc.meta.teach.family == "星宿派", "#{name} teach.family"
        assert map_size(npc.meta.teach.teach_skills) > 0, "#{name} teach_skills"
        assert npc.meta.apprentice.family == "星宿派", "#{name} apprentice.family"
      end
    end

    test "no_teach 逐技能 map 与 LPC 原文一致", %{world: world} do
      assert inquiry(xx(world, "阿紫"), "木鼎") == "仓库里面一大堆，你自己去找吧！"

      for {name, text} <- [
            {"阿紫", "化功大法让老仙教你吧，我可不愿被他罚。"},
            {"狮吼子", "化功大法要老仙亲自传授。"},
            {"天狼子", "化功大法要老仙亲自传授。"},
            {"摘星子", "化功大法要老仙亲自传授。"}
          ] do
        npc = xx(world, name)
        assert npc.meta.teach.no_teach_deny["huagong-dafa"] == text
        refute Map.has_key?(npc.meta.teach.teach_skills, "huagong-dafa")
      end

      assert is_nil(xx(world, "丁春秋").meta.teach.no_teach_deny["huagong-dafa"])
    end

    @xingxiu_grants [
      {"摘星子", "如蛆附骨", "tianshan-zhang/fugu", -2200, 80, %{"tianshan-zhang" => 60}, 80, nil},
      {"摘星子", "冰雪纷飞", "tianshan-zhang/xue", -22000, 80, %{"tianshan-zhang" => 60}, 80, nil},
      {"摘星子", "满天花雨", "feixing-shu/hua", -5500, 400, %{"feixing-shu" => 100, "force" => 120}, nil,
       nil},
      {"摘星子", "锁魂势", "chanhun-suo/suo", -6500, 400, %{"chanhun-suo" => 70, "force" => 120}, nil,
       nil},
      {"摘星子", "三阴毒爪", "sanyin-wugongzhao/zhua", -7000, 500,
       %{"sanyin-wugongzhao" => 100, "force" => 100}, nil, nil},
      {"摘星子", "腐尸毒", "chousui-zhang/shi", -10000, 500,
       %{"chousui-zhang" => 140, "force" => 120, "poison" => 150, "throwing" => 120}, nil, 1200},
      {"丁春秋", "夺魂势", "chanhun-suo/duo", -10000, 80, %{"chanhun-suo" => 100, "force" => 130}, 80,
       nil},
      {"丁春秋", "炼心弹", "chousui-zhang/dan", -22000, 950,
       %{"chousui-zhang" => 140, "force" => 140, "poison" => 140, "throwing" => 140}, nil, 1800},
      {"丁春秋", "碧焰滔天", "chousui-zhang/tao", -38000, 1200,
       %{"chousui-zhang" => 220, "poison" => 250, "huagong-dafa" => 220}, nil, 3000}
    ]

    test "九条 sect_master_grant 的门控字段与 masterd.c 一致", %{world: world} do
      for {name, key, perform_id, shen, gong, levels, min_force, neili} <- @xingxiu_grants do
        cfg = inquiry(xx(world, name), key)
        assert cfg["kind"] == "sect_master_grant", "#{name}/#{key}"
        assert cfg["gate_order"] == "lpc_masterd", "#{name}/#{key}"
        assert cfg["perform_id"] == perform_id, "#{name}/#{key}"
        assert cfg["max_shen"] == shen, "#{name}/#{key}"
        assert cfg["min_gongxian"] == gong, "#{name}/#{key}"
        assert cfg["cost_gongxian"] == gong, "#{name}/#{key}"
        assert cfg["min_levels"] == levels, "#{name}/#{key}"
        assert cfg["min_force"] == min_force, "#{name}/#{key}"
        assert cfg["min_max_neili"] == neili, "#{name}/#{key}"
        assert is_list(cfg["level_order"]) and length(cfg["level_order"]) > 0, "#{name}/#{key}"
      end
    end

    test "如蛆附骨：sk1 等级门先于 masterd force 字段门", %{world: world} do
      zhaixing = xx(world, "摘星子")
      cfg = inquiry(zhaixing, "如蛆附骨")

      base = %{
        family: "星宿派",
        shen: -3000,
        gongxian: 80,
        skills: %{"tianshan-zhang" => 60, "force" => 79}
      }

      assert {:error, "你目前的内功火候不足，下去练练再来吧。"} =
               SectMaster.inquiry_grant(disciple(base), zhaixing, cfg)

      assert {:error, "你对天山杖法的了解还不够，尚且无法领悟此招。\n"} =
               SectMaster.inquiry_grant(
                 disciple(%{base | skills: %{"tianshan-zhang" => 59, "force" => 120}}),
                 zhaixing,
                 cfg
               )

      assert {:ok, "tianshan-zhang/fugu", 80} =
               SectMaster.inquiry_grant(
                 disciple(%{base | skills: %{"tianshan-zhang" => 60, "force" => 80}}),
                 zhaixing,
                 cfg
               )
    end

    test "腐尸毒：四项技能之后才判 max_neili 1200", %{world: world} do
      zhaixing = xx(world, "摘星子")
      cfg = inquiry(zhaixing, "腐尸毒")

      base = %{
        family: "星宿派",
        shen: -20_000,
        gongxian: 500,
        max_neili: 1200,
        skills: %{
          "chousui-zhang" => 140,
          "force" => 120,
          "poison" => 150,
          "throwing" => 120
        }
      }

      assert {:error, "你现在的内力修为不足，修炼高点再来吧。"} =
               SectMaster.inquiry_grant(disciple(%{base | max_neili: 1199}), zhaixing, cfg)

      assert {:ok, "chousui-zhang/shi", 500} =
               SectMaster.inquiry_grant(disciple(base), zhaixing, cfg)
    end

    test "夺魂势保留 sk2 force 130 与独立 force 80 两道门", %{world: world} do
      ding = xx(world, "丁春秋")
      cfg = inquiry(ding, "夺魂势")

      base = %{
        family: "星宿派",
        shen: -20_000,
        gongxian: 80,
        skills: %{"chanhun-suo" => 100, "force" => 100}
      }

      assert {:error, "你对基本内功的了解还不够，尚且无法领悟此招。\n"} =
               SectMaster.inquiry_grant(disciple(base), ding, cfg)

      assert {:ok, "chanhun-suo/duo", 80} =
               SectMaster.inquiry_grant(
                 disciple(%{base | skills: %{"chanhun-suo" => 100, "force" => 130}}),
                 ding,
                 cfg
               )
    end

    test "物品问询、计数库存与 GAP #813/#814 标记", %{world: world} do
      ding = xx(world, "丁春秋")
      zhaixing = xx(world, "摘星子")

      assert inquiry(ding, "毒经")["kind"] == "give_item"
      assert inquiry(ding, "毒经")["item"] == "clone_lib:dujing_2"
      assert inquiry(ding, "星宿毒经")["count"] == "book_count"
      assert inquiry(ding, "碧磷针")["item"] == "xiyu:bilinzhen"
      assert inquiry(ding, "碧磷针")["min_skill_levels"] == %{"poison" => 50}
      assert inquiry(ding, "逍遥三笑散")["min_skill_levels"] == %{"poison" => 100}
      assert inquiry(ding, "香料")["min_skill_levels"] == %{"poison" => 40}
      assert inquiry(ding, "柔丝索")["master_id"] == "true"
      assert inquiry(ding, "柔丝索")["max_shen"] == -30000
      assert inquiry(ding, "神木王鼎") =~ "休想打它的注意"

      assert inquiry(zhaixing, "炼心弹")["item"] == "xiyu:lianxindan"
      assert inquiry(zhaixing, "秘籍")["item"] == "clone_lib:throw_book"
      assert inquiry(zhaixing, "天山器法")["count"] == "book_count"
      assert ding.meta.inquiry_state["xiangliao_count"] == 10
      assert zhaixing.meta.inquiry_state["dan_count"] == 1

      assert inquiry(ding, "历练") =~ "GAP #813"
      assert inquiry(ding, "历炼") =~ "GAP #813"
      assert inquiry(ding, "锻炼") =~ "GAP #813"
    end

    test "收徒门控：摘星子 shen<=0、丁春秋负神与技能链", %{world: world} do
      zhaixing = xx(world, "摘星子").meta.apprentice
      assert zhaixing.no_min_shen == true
      assert zhaixing.max_shen == 0
      assert zhaixing.max_shen_deny =~ "老仙最讨厌你们这些正道中人"

      ding = xx(world, "丁春秋").meta.apprentice
      assert ding.no_min_shen == true
      assert ding.max_shen == -12000
      assert ding.min_exp == 300_000
      assert ding.min_skills == %{"chousui-zhang" => 120, "poison" => 120}
      assert ding.min_skills_deny["poison"] == "你毒技都没学明白，还有脸来见我？"

      for name <- ["阿紫", "出尘子", "星宿弟子", "狮吼子", "天狼子"] do
        assert xx(world, name).meta.apprentice.deny_all == true, name
      end
    end
  end

  describe "玄冥谷 UCL 数据回填（Task #817）" do
    @describetag :xuanming
    defp xm(world, name) do
      npc = Enum.find(world.characters, &(&1.name == name))
      assert npc, "#{name} 应随世界加载"
      npc
    end

    @xuanming_names ["百损道人", "鹤笔翁", "鹿杖客", "乌旺阿普"]

    test "四名玄冥 NPC 全部带 teach 与 apprentice 数据", %{world: world} do
      for name <- @xuanming_names do
        npc = xm(world, name)
        assert npc.meta.teach.family == "玄冥谷", "#{name} teach.family"
        assert map_size(npc.meta.teach.teach_skills) > 0, "#{name} teach_skills"
        assert npc.meta.apprentice.family == "玄冥谷", "#{name} apprentice.family"
      end
    end

    test "no_teach 逐技能 map 与 LPC 原文一致且从 teach_skills 剔除", %{world: world} do
      he = xm(world, "鹤笔翁")

      assert he.meta.teach.no_teach_deny["xuanming-shengong"] ==
               "玄冥神功要我师父百损道人亲自传授。"

      assert he.meta.teach.no_teach_deny["xuanming-zhang"] ==
               "玄冥神掌要我师父亲自传授，你还是去找他老人家吧！"

      assert he.meta.teach.no_teach_deny["dulong-shenzhua"] ==
               "这个你还是找我师兄鹿杖客吧，他比我厉害多了！"

      lu = xm(world, "鹿杖客")

      assert lu.meta.teach.no_teach_deny["xuanming-shengong"] ==
               "玄冥神功要我师父百损道人亲自传授。"

      assert lu.meta.teach.no_teach_deny["xuanming-zhang"] ==
               "玄冥神掌要我师父亲自传授，你还是去找他老人家吧！"

      for npc <- [he, lu] do
        for skill <- ["xuanming-shengong", "xuanming-zhang"] do
          refute Map.has_key?(npc.meta.teach.teach_skills, skill)
        end
      end

      refute Map.has_key?(he.meta.teach.teach_skills, "dulong-shenzhua")
      assert Map.has_key?(xm(world, "百损道人").meta.teach.teach_skills, "xuanming-zhang")
    end

    @xuanming_grants [
      {"百损道人", "蛟龙抱", "dulong-shenzhua/bao", -38000, 420, %{"dulong-shenzhua" => 100}, nil, 150,
       nil},
      {"百损道人", "真龙聚", "dulong-shenzhua/ju", -43000, 580, %{"dulong-shenzhua" => 130}, 180, nil,
       nil},
      {"百损道人", "惊涛骇浪", "xuanming-zhang/lang", -68000, 1200,
       %{"xuanming-zhang" => 180, "xuanming-shengong" => 180}, nil, nil, 3000},
      {"百损道人", "玄冥双行", "xuanming-zhang/xing", -108_000, 1500,
       %{"xuanming-zhang" => 220, "xuanming-shengong" => 220}, nil, nil, 4000},
      {"鹤笔翁", "掌打飞花", "feihua-zhang/fei", -2000, 100, %{"feihua-zhang" => 40}, nil, nil, nil},
      {"鹤笔翁", "卷字决", "piaofeng-quan/juan", -500, 80, %{"piaofeng-quan" => 30}, nil, nil, nil},
      {"鹤笔翁", "残月刺", "jingyue-bifa/ci", -2400, 200, %{"jingyue-bifa" => 30}, nil, nil, nil},
      {"鹤笔翁", "内点乾坤", "hexing-bifa/dian", -8000, 320, %{"hexing-bifa" => 100}, nil, nil, nil},
      {"鹤笔翁", "如影相随", "xuanming-zhang/ying", -32000, 380, %{"xuanming-zhang" => 100}, nil, 180,
       nil},
      {"鹿杖客", "缤纷雪舞", "ningxue-zhang/xue", -20000, 220, %{"ningxue-zhang" => 50}, nil, nil, nil},
      {"鹿杖客", "通天彻地", "lutou-zhang/tong", -23000, 380, %{"lutou-zhang" => 100}, 140, nil, nil},
      {"鹿杖客", "只手遮天", "xuanming-zhang/zhe", -50000, 880,
       %{"xuanming-zhang" => 150, "xuanming-shengong" => 150}, nil, nil, 2000}
    ]

    test "十二条 sect_master_grant 的门控字段与 masterd.c 一致", %{world: world} do
      for {name, key, perform_id, shen, gong, levels, force, dodge, neili} <- @xuanming_grants do
        cfg = inquiry(xm(world, name), key)
        assert cfg["kind"] == "sect_master_grant", "#{name}/#{key}"
        assert cfg["gate_order"] == "lpc_masterd", "#{name}/#{key}"
        assert cfg["perform_id"] == perform_id, "#{name}/#{key}"
        assert cfg["max_shen"] == shen, "#{name}/#{key}"
        assert cfg["min_gongxian"] == gong, "#{name}/#{key}"
        assert cfg["cost_gongxian"] == gong, "#{name}/#{key}"
        assert cfg["min_levels"] == levels, "#{name}/#{key}"
        assert cfg["min_force"] == force, "#{name}/#{key}"
        assert cfg["min_dodge"] == dodge, "#{name}/#{key}"
        assert cfg["min_max_neili"] == neili, "#{name}/#{key}"
        assert is_list(cfg["level_order"]) and length(cfg["level_order"]) > 0, "#{name}/#{key}"
      end
    end

    test "蛟龙抱：主技能门之后才判独立 dodge 150", %{world: world} do
      bai = xm(world, "百损道人")
      cfg = inquiry(bai, "蛟龙抱")

      base = %{
        family: "玄冥谷",
        shen: -40_000,
        gongxian: 420,
        skills: %{"dulong-shenzhua" => 100, "dodge" => 149}
      }

      assert {:error, "你目前的轻功火候不足，下去练练再来吧。"} = SectMaster.inquiry_grant(disciple(base), bai, cfg)

      assert {:ok, "dulong-shenzhua/bao", 420} =
               SectMaster.inquiry_grant(
                 disciple(%{base | skills: %{"dulong-shenzhua" => 100, "dodge" => 150}}),
                 bai,
                 cfg
               )
    end

    test "真龙聚与惊涛骇浪：force/neili 独立门按 LPC 阈值", %{world: world} do
      bai = xm(world, "百损道人")
      ju = inquiry(bai, "真龙聚")

      low_force =
        disciple(%{
          family: "玄冥谷",
          shen: -50_000,
          gongxian: 580,
          skills: %{"dulong-shenzhua" => 130, "force" => 179}
        })

      assert {:error, "你目前的内功火候不足，下去练练再来吧。"} = SectMaster.inquiry_grant(low_force, bai, ju)

      assert {:ok, "dulong-shenzhua/ju", 580} =
               SectMaster.inquiry_grant(
                 disciple(%{low_force | skills: %{"dulong-shenzhua" => 130, "force" => 180}}),
                 bai,
                 ju
               )

      lang = inquiry(bai, "惊涛骇浪")

      base = %{
        family: "玄冥谷",
        shen: -70_000,
        gongxian: 1200,
        max_neili: 3000,
        skills: %{"xuanming-zhang" => 180, "xuanming-shengong" => 180}
      }

      assert {:error, "你现在的内力修为不足，修炼高点再来吧。"} =
               SectMaster.inquiry_grant(disciple(%{base | max_neili: 2999}), bai, lang)

      assert {:ok, "xuanming-zhang/lang", 1200} =
               SectMaster.inquiry_grant(disciple(base), bai, lang)
    end

    test "鹤形笔/鹿头杖 give_item 与 QUEST_D、owner traversal GAP 标记", %{world: world} do
      he = xm(world, "鹤笔翁")
      bi = inquiry(he, "鹤形笔")
      assert bi["kind"] == "give_item"
      assert bi["item"] == "clone_lib:hexingbi"
      assert bi["min_skill_levels"] == %{"hexing_bifa" => 100}
      assert bi["max_shen"] == -10000
      refute Map.has_key?(bi, "master_id")
      assert bi["note"] =~ "GAP #820"

      zhang = inquiry(xm(world, "鹿杖客"), "鹿头杖")
      assert zhang["item"] == "clone_lib:lutouzhang"
      assert zhang["min_skill_levels"] == %{"lutou_zhang" => 100}
      assert zhang["max_shen"] == -20000
      assert zhang["master_id"] == "true"
      assert zhang["note"] =~ "GAP #820"

      assert inquiry(xm(world, "百损道人"), "历练") =~ "GAP #818"
      assert inquiry(xm(world, "百损道人"), "历炼") =~ "GAP #818"
      assert inquiry(xm(world, "百损道人"), "锻炼") =~ "GAP #818"
      assert xm(world, "百损道人").meta.inquiries["鹿杖客"] == "他是我大徒弟。"
    end

    test "收徒门控：百损/鹿杖客 skills 先于 exp，鹤笔翁负神门，乌旺阿普拒收", %{world: world} do
      bai = xm(world, "百损道人").meta.apprentice
      assert bai.gate_order == "lpc_xuanming"
      assert bai.no_min_shen == true
      assert bai.max_shen == -35000
      assert bai.max_shen_deny == "哼，我百损道人从不和正道中人交往。"
      assert bai.min_skills == %{"minggu-xinfa" => 160, "strike" => 160}
      assert bai.min_skills_deny["minggu-xinfa"] =~ "冥谷心法火候不足"
      assert bai.min_exp == 500_000

      lu = xm(world, "鹿杖客").meta.apprentice
      assert lu.gate_order == "lpc_xuanming"
      assert lu.max_shen == -20000
      assert lu.min_skills == %{"minggu-xinfa" => 120, "strike" => 120}
      assert lu.min_exp == 0

      he = xm(world, "鹤笔翁").meta.apprentice
      assert he.no_min_shen == true
      assert he.max_shen == 0
      assert he.max_shen_deny =~ "正道人士交往"

      assert xm(world, "乌旺阿普").meta.apprentice.deny_all == true
    end
  end

  # ---------------------------------------------------------------------------
  # 镇远镖局（zhenyuan / 八卦门）—— Task #619 本批
  # LPC: kungfu/class/zhenyuan/{zhenyuan.h,wangweiyang,wangjianying,wangjianjie,daiyongming,tongzhaohe}.c
  # ---------------------------------------------------------------------------
  describe "镇远镖局 UCL 数据回填（Task #619）" do
    defp zy(world, name, room) do
      npc = npc(world, name, room)
      assert npc, "#{name} 应随世界加载（#{room}）"
      npc
    end

    test "五名镖局 NPC 全部带 teach 与 apprentice 数据", %{world: world} do
      # 王剑杰 16（19 set_skill 中 3 项入 no_teach）、王剑英 17（19 中 2 项入 no_teach），
      # 均按玄冥谷约定从 teach_skills 剔除（no_teach 逐技能硬拒见下两条测试）。
      for {name, room, skills} <- [
            {"王维扬", "beijing:shufang", 22},
            {"王剑杰", "beijing:zhengting", 16},
            {"王剑英", "beijing:son_cabinet1", 17},
            {"戴永明", "beijing:front_yard2", 13},
            {"童兆和", "beijing:gate", 13}
          ] do
        npc = zy(world, name, room)

        assert npc.meta.teach, "#{name} 应有 teach"
        assert npc.meta.teach.family == "八卦门", "#{name} teach.family"

        assert map_size(npc.meta.teach.teach_skills) == skills,
               "#{name} teach_skills 应为 #{skills} 项，实际 #{map_size(npc.meta.teach.teach_skills)}"

        assert npc.meta.apprentice, "#{name} 应有 apprentice"
        assert npc.meta.apprentice.family == "八卦门", "#{name} apprentice.family"
        assert npc.meta.apprentice.permit_recruit == true, "#{name} permit_recruit"
        # zhenyuan.h permit_recruit 三句逐字覆写
        assert npc.meta.apprentice.betray_sect_deny =~ "离开了咱镖局"
        assert npc.meta.apprentice.betray_times_deny =~ "背信弃义"
        assert npc.meta.apprentice.other_family_deny == "不妥，不妥！你已经有师承了。"
      end
    end

    test "五名镖局 NPC combat 属性完整（防 inquiry 回填时 combat 块被误删）", %{
      world: world
    } do
      # 王维扬 / 王剑杰 的 combat 块曾在 inquiry 回填时被误删（测试不覆盖战斗属性→未报警），
      # 本测试锁定二者 combat_exp / max_neili / max_qi / max_jing，防回归。
      wwy = zy(world, "王维扬", "beijing:shufang")
      assert wwy.meta.stats.combat_exp == 3_500_000
      assert wwy.meta.vitals.max_neili == 5800
      assert wwy.meta.vitals.max_qi == 5200
      assert wwy.meta.vitals.max_jing == 4000

      wjj = zy(world, "王剑杰", "beijing:zhengting")
      assert wjj.meta.stats.combat_exp == 1_500_000
      assert wjj.meta.vitals.max_neili == 3200
      assert wjj.meta.vitals.max_qi == 3500
      assert wjj.meta.vitals.max_jing == 3500

      # 另三名也须有 combat（combat_exp > 0）
      for {name, room} <- [
            {"王剑英", "beijing:son_cabinet1"},
            {"戴永明", "beijing:front_yard2"},
            {"童兆和", "beijing:gate"}
          ] do
        assert zy(world, name, room).meta.stats.combat_exp > 0, "#{name} 应带 combat"
      end
    end

    test "王剑杰 no_teach 三条逐技能 map（由父/兄亲授）", %{world: world} do
      npc = zy(world, "王剑杰", "beijing:zhengting")

      assert npc.meta.teach.no_teach ==
               ["wai-bagua", "nei-bagua", "bagua-dao"]

      deny = npc.meta.teach.no_teach_deny
      assert deny["wai-bagua"] == "这个…外八卦神功…你还是找我爹或是我哥教你好了。"
      assert deny["nei-bagua"] == "我爹说过了，内八卦神功不能随便传授，你直接找我爹好了。"
      assert deny["bagua-dao"] == "八卦刀法向来便是由我父亲亲自教授。"

      # no_teach 的技能不得同时出现在 teach_skills 里
      for s <- ["wai-bagua", "nei-bagua", "bagua-dao"] do
        refute Map.has_key?(npc.meta.teach.teach_skills, s), "#{s} 不应同时在 teach_skills"
      end
    end

    test "王剑英 no_teach 两条逐技能 map（内八卦/八卦刀由父授）", %{world: world} do
      npc = zy(world, "王剑英", "beijing:son_cabinet1")

      assert npc.meta.teach.no_teach == ["nei-bagua", "bagua-dao"]
      assert npc.meta.teach.no_teach_deny["nei-bagua"] == "内八卦神功必须由我父亲亲自传授。"
      assert npc.meta.teach.no_teach_deny["bagua-dao"] == "八卦刀法向来便是由我父亲亲自教授。"
    end

    test "王维扬 7 门绝招 + 厚背紫金刀 give_item：门控字段与 ask_skill1-7 一致", %{
      world: world
    } do
      npc = zy(world, "王维扬", "beijing:shufang")

      # {key, perform_id, skill, gongxian, levels, level_order}
      expected = [
        {"八卦震", "wai-bagua/zhen", "wai-bagua", 100, %{"force" => 100, "wai-bagua" => 60},
         ["force", "wai-bagua"]},
        {"神卦天印", "bazhen-zhang/yin", "bazhen-zhang", 500,
         %{"force" => 180, "bazhen-zhang" => 130}, ["force", "bazhen-zhang"]},
        {"乾坤一掷", "bagua-biao/zhi", "bagua-biao", 800, %{"force" => 200, "bagua-biao" => 120},
         ["force", "bagua-biao"]},
        {"翻卦连环掌", "youshen-zhang/fan", "youshen-zhang", 500,
         %{"force" => 160, "youshen-zhang" => 120}, ["force", "youshen-zhang"]},
        {"劈天神芒", "bagua-dao/mang", "bagua-dao", 1000,
         %{"bagua-dao" => 140, "wai-bagua" => 140, "force" => 200},
         ["bagua-dao", "wai-bagua", "force"]},
        {"天刀八势", "bagua-dao/tian", "bagua-dao", 2400,
         %{"bagua-dao" => 200, "wai-bagua" => 200, "nei-bagua" => 200, "max-neili" => 3200},
         ["bagua-dao", "wai-bagua", "nei-bagua", "max-neili"]},
        {"杀龙无悔", "bagua-dao/sha", "bagua-dao", 1800, %{"bagua-dao" => 180, "force" => 250},
         ["bagua-dao", "force"]}
      ]

      for {key, perform_id, skill, gongxian, levels, order} <- expected do
        cfg = inquiry(npc, key)
        assert cfg, "王维扬应能回答「#{key}」"
        assert cfg["kind"] == "sect_master_grant", key
        assert cfg["gate_order"] == "lpc_kunlun", key
        assert cfg["perform_id"] == perform_id, key
        assert cfg["skill"] == skill, key
        assert cfg["min_gongxian"] == gongxian, key
        assert cfg["cost_gongxian"] == gongxian, key
        assert cfg["min_levels"] == levels, key
        assert cfg["level_order"] == order, key
        assert cfg["family"] == "八卦门", key
      end

      # 逐招 maxed 文案（LPC 原文，各招不同）
      assert inquiry(npc, "八卦震")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "神卦天印")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "乾坤一掷")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "翻卦连环掌")["maxed"] == "这招我已经教过你了，自己下去练吧。"
      assert inquiry(npc, "劈天神芒")["maxed"] == "我不是已经教会你了吗？"
      assert inquiry(npc, "天刀八势")["maxed"] == "你不是已经学会了吗？怎么，又给忘记了？"
      assert inquiry(npc, "杀龙无悔")["maxed"] == "唉…你自己下去练吧。"

      # learned 文案不带字面 \n：引擎 render("text") 逐字渲染，`\n` 不会被显示层
      # 反转义（与 clone_lib 168/293 主约定一致，本批全 8 NPC 统一不带 \n）。
      assert inquiry(npc, "八卦震")["learned"] == "你学会了「八卦震」。"
      assert inquiry(npc, "神卦天印")["learned"] == "你学会了「神卦天印」。"
      assert inquiry(npc, "乾坤一掷")["learned"] == "你学会了「乾坤一掷」。"
      assert inquiry(npc, "翻卦连环掌")["learned"] == "你学会了「翻卦连环掌」。"
      assert inquiry(npc, "劈天神芒")["learned"] == "你学会了「劈天神芒」。"
      assert inquiry(npc, "天刀八势")["learned"] == "你学会了「天刀八势」。"
      assert inquiry(npc, "杀龙无悔")["learned"] == "你学会了「杀龙无悔」。"

      # 天刀八势的四连提升 + 内力上界门槛
      tian = inquiry(npc, "天刀八势")
      assert tian["min_levels"]["max-neili"] == 3200
      assert tian["level_deny"]["max-neili"] =~ "内力修为不足"

      assert length(tian["improve_skills"]) == 19,
             "天刀八势 应有 19 次 improve_skill（force×3/nei×3/parry×3/wai×3/blade×3/bagua×3/martial-cognize）"

      assert Enum.count(tian["improve_skills"], &(&1 == "force")) == 3
      assert Enum.count(tian["improve_skills"], &(&1 == "nei-bagua")) == 3
      assert Enum.count(tian["improve_skills"], &(&1 == "bagua-dao")) == 3

      # 杀龙无悔 的 shen 门在 LPC 已被注释 → 不得配置
      refute Map.has_key?(inquiry(npc, "杀龙无悔"), "max_shen")
      refute Map.has_key?(inquiry(npc, "杀龙无悔"), "min_shen")

      # 厚背紫金刀：give_item + master_id + 八卦刀 120 + 八卦门
      dao = inquiry(npc, "厚背紫金刀")
      assert dao["kind"] == "give_item"
      assert dao["item"] == "clone_lib:houbeidao"
      assert dao["unique"] == "true"
      assert dao["family"] == "八卦门"
      assert dao["master_id"] == "true"
      assert dao["min_skill_levels"] == %{"bagua_dao" => 120}
      assert dao["family_deny"] =~ "厚背紫金八卦刀是我八卦门的至宝"
      assert dao["master_deny"] =~ "只有我的弟子才配用厚背紫金刀"
      assert dao["min_skill_deny"] =~ "下去再练练你的八卦刀法"
    end

    test "王剑杰 3 门 / 王剑英 2 门：level_order 与逐条文案落位", %{world: world} do
      jie = zy(world, "王剑杰", "beijing:zhengting")

      for {key, perform_id, gongxian, levels, order} <- [
            {"劈卦拳", "bagua-quan/gua", 100, %{"force" => 100, "bagua-quan" => 70},
             ["force", "bagua-quan"]},
            {"背心钉", "bagua-zhang/ding", 150, %{"force" => 120, "bagua-zhang" => 80},
             ["force", "bagua-zhang"]},
            {"蝰蟒盘身", "kuimang-dao/pan", 50, %{"force" => 60, "kuimang-dao" => 40},
             ["force", "kuimang-dao"]}
          ] do
        cfg = inquiry(jie, key)
        assert cfg["gate_order"] == "lpc_kunlun", key
        assert cfg["perform_id"] == perform_id, key
        assert cfg["min_gongxian"] == gongxian, key
        assert cfg["cost_gongxian"] == gongxian, key
        assert cfg["min_levels"] == levels, key
        assert cfg["level_order"] == order, key
        assert cfg["gongxian_deny"] == "你为镖局出力不够，这招我暂时不忙传你。", key
      end

      assert inquiry(jie, "劈卦拳")["skill_deny"] == "你连八卦拳法都没学，还谈什么绝招可言？"
      assert inquiry(jie, "背心钉")["skill_deny"] == "你连八卦掌法都没学，还谈什么绝招可言？"
      assert inquiry(jie, "蝰蟒盘身")["skill_deny"] == "你连蝰蟒刀法都没学，还谈什么绝招可言？"

      # learned 不带字面 \n（本批统一约定，同王维扬）
      assert inquiry(jie, "劈卦拳")["learned"] == "你学会了「劈卦拳」。"
      assert inquiry(jie, "背心钉")["learned"] == "你学会了「背心钉」。"
      assert inquiry(jie, "蝰蟒盘身")["learned"] == "你学会了「蝰蟒盘身」。"

      ying = zy(world, "王剑英", "beijing:son_cabinet1")

      for key <- ["掌中夹镖", "镖中现掌"] do
        cfg = inquiry(ying, key)
        assert cfg["gate_order"] == "lpc_kunlun", key
        assert cfg["family"] == "八卦门", key
        assert cfg["min_gongxian"] == 400, key
        assert cfg["cost_gongxian"] == 400, key
        # 双技能存在门：bagua-zhang 与 bagua-biao 都进 level_order
        assert cfg["level_order"] == ["bagua-zhang", "bagua-biao", "force"], key
        assert cfg["min_levels"]["bagua-zhang"] == 120, key
        assert cfg["min_levels"]["bagua-biao"] == 120, key
        assert cfg["skill_deny"] == "你连八卦掌都没学，谈什么绝招？", key
      end

      assert inquiry(ying, "掌中夹镖")["learned"] == "你学会了「掌中夹镖」。"
      assert inquiry(ying, "镖中现掌")["learned"] == "你学会了「镖中现掌」。"

      assert inquiry(ying, "掌中夹镖")["perform_id"] == "bagua-zhang/jia"

      assert inquiry(ying, "掌中夹镖")["maxed"] ==
               "该说的我都说完了，还有什么不明白就自己下去练！"

      assert inquiry(ying, "镖中现掌")["perform_id"] == "bagua-biao/xian"
      assert inquiry(ying, "镖中现掌")["maxed"] == "嗯？这招不是已经教过你了吗？"
      assert inquiry(ying, "掌中夹镖")["min_levels"]["force"] == 150
      assert inquiry(ying, "镖中现掌")["min_levels"]["force"] == 200
    end

    test "收徒门控：exp 与 bagua-xinfa 门槛按 LPC 逐 NPC 落位", %{world: world} do
      # 王维扬：exp 320000 + bagua-xinfa 100
      wwy = zy(world, "王维扬", "beijing:shufang").meta.apprentice
      assert wwy.min_exp == 320_000
      assert wwy.min_skills == %{"bagua-xinfa" => 100}
      assert wwy.min_exp_deny =~ "我收徒可是件大事"

      # 王剑杰：仅 exp 20000
      wjj = zy(world, "王剑杰", "beijing:zhengting").meta.apprentice
      assert wjj.min_exp == 20000
      assert wjj.min_skills == %{}
      assert wjj.min_exp_deny =~ "再摸爬滚打一段时间"

      # 王剑英：exp 100000 + bagua-xinfa 80
      wjy = zy(world, "王剑英", "beijing:son_cabinet1").meta.apprentice
      assert wjy.min_exp == 100_000
      assert wjy.min_skills == %{"bagua-xinfa" => 80}
      assert wjy.min_skills_deny["bagua-xinfa"] =~ "内功修为太差"

      # 戴永明/童兆和：无 exp / 无技能门（permit_recruit 后即收）
      for {name, room} <- [{"戴永明", "beijing:front_yard2"}, {"童兆和", "beijing:gate"}] do
        a = zy(world, name, room).meta.apprentice
        assert a.min_exp == 0, name
        assert a.min_skills == %{}, name
      end

      # accept_msg 逐字
      assert zy(world, "戴永明", "beijing:front_yard2").meta.apprentice.accept_msg ==
               "既然这样，那你就留下吧。"

      assert zy(world, "童兆和", "beijing:gate").meta.apprentice.accept_msg ==
               "居然有人拜我为师？念在你有心，我就收下你好了。"
    end

    test "王维扬 accept 规则：收信传功 / 收刀 三分支文案落位", %{world: world} do
      npc = zy(world, "王维扬", "beijing:shufang")
      rules = npc.meta.accept
      assert is_list(rules) and length(rules) == 1
      rule = hd(rules)
      assert rule.kind == "any"
      assert rule.accept == true

      # 8 条分支文案（LPC accept_object：非刀非信 / 信件传功 / 交回刀·外人 / 交回刀·弟子，
      # 各含 msg + 动作回显 shake/shit/nod/haha）
      assert length(rule.msg) == 8
      assert Enum.at(rule.msg, 0) == "你给我这种东西干什么？"
      assert Enum.at(rule.msg, 1) =~ "我就传你这招「天刀八势」"
      assert Enum.at(rule.msg, 2) == "很好，很好！"
    end

    test "王维扬 engage：拒绝比武（LPC accept_fight 返回 0）", %{world: world} do
      npc = zy(world, "王维扬", "beijing:shufang")
      # LPC accept_fight → command("say ...你不是我的对手...") + return 0
      assert npc.meta.engage[:fight].accept == false
    end

    test "门控联验：王维扬 八卦震 按 LPC 顺序逐条拒绝", %{world: world} do
      npc = zy(world, "王维扬", "beijing:shufang")
      cfg = inquiry(npc, "八卦震")

      base = %{
        family: "八卦门",
        shen: 0,
        gongxian: 100,
        performs: MapSet.new(),
        skills: %{"force" => 100, "wai-bagua" => 60}
      }

      # 达标
      assert {:ok, "wai-bagua/zhen", 100} =
               SectMaster.inquiry_grant(disciple(base), npc_stats(npc), cfg)

      # 非同门 → family_deny（在「已会」之后）
      other = disciple(%{base | family: "商家堡"})
      assert {:error, "大侠和本镖局素无来往，何出此言？\n"} = SectMaster.inquiry_grant(other, npc_stats(npc), cfg)

      # 未学外八卦 → skill_deny
      no_skill = disciple(%{base | skills: %{"force" => 100}})

      assert {:error, "你连外八卦都没学，谈什么绝招？\n"} =
               SectMaster.inquiry_grant(no_skill, npc_stats(npc), cfg)

      # 贡献不足 → gongxian_deny
      low_gong = disciple(%{base | gongxian: 50})

      assert {:error, "你在镖局内碌碌无为，这一招我暂时还不能传你。\n"} =
               SectMaster.inquiry_grant(low_gong, npc_stats(npc), cfg)

      # force 先于外八卦等级（level_order = [force, wai-bagua]）
      force_low = disciple(%{base | skills: %{"force" => 99, "wai-bagua" => 60}})

      assert {:error, "你的内功火候尚需提高，练好了再来找我吧。\n"} =
               SectMaster.inquiry_grant(force_low, npc_stats(npc), cfg)

      # 外八卦等级不足 → 外八卦文案（不是内功文案）
      quan_low = disciple(%{base | skills: %{"force" => 100, "wai-bagua" => 59}})

      assert {:error, "你的外八卦还练得不到家，自己下去练练再来吧！\n"} =
               SectMaster.inquiry_grant(quan_low, npc_stats(npc), cfg)

      # 已学会 → maxed
      known = disciple(%{base | performs: MapSet.new(["wai-bagua/zhen"])})

      assert {:error, "这招我已经教过你了，自己下去练吧。\n"} =
               SectMaster.inquiry_grant(known, npc_stats(npc), cfg)
    end

    test "门控联验：天刀八势 max-neili 在最终技能等级之后判定", %{world: world} do
      npc = zy(world, "王维扬", "beijing:shufang")
      cfg = inquiry(npc, "天刀八势")

      base = %{
        family: "八卦门",
        shen: 0,
        gongxian: 2400,
        skills: %{"bagua-dao" => 200, "wai-bagua" => 200, "nei-bagua" => 200},
        max_neili: 3200
      }

      assert {:ok, "bagua-dao/tian", 2400} =
               SectMaster.inquiry_grant(disciple(base), npc_stats(npc), cfg)

      # 内八卦不足 → 内八卦文案（在 max-neili 之前）
      nei_low =
        disciple(%{base | skills: %{"bagua-dao" => 200, "wai-bagua" => 200, "nei-bagua" => 199}})

      assert {:error, "你的内八卦神功还练得不到家，自己下去练练再来吧！\n"} =
               SectMaster.inquiry_grant(nei_low, npc_stats(npc), cfg)

      # 内力不足 → max_neili 文案（排在四个技能之后）
      neili_low = disciple(%{base | max_neili: 3199})

      assert {:error, "你的内力修为不足，施展不出这招，等你内力有所攀升后再来找我吧。\n"} =
               SectMaster.inquiry_grant(neili_low, npc_stats(npc), cfg)
    end

    test "门控联验：王剑英 掌中夹镖 force 排在双技能之后", %{world: world} do
      npc = zy(world, "王剑英", "beijing:son_cabinet1")
      cfg = inquiry(npc, "掌中夹镖")

      base = %{
        family: "八卦门",
        shen: 0,
        gongxian: 400,
        skills: %{"bagua-zhang" => 120, "bagua-biao" => 120, "force" => 150}
      }

      assert {:ok, "bagua-zhang/jia", 400} =
               SectMaster.inquiry_grant(disciple(base), npc_stats(npc), cfg)

      # 八卦镖不足 → 八卦镖文案（force 之后才判）
      biao_low =
        disciple(%{base | skills: %{"bagua-zhang" => 120, "bagua-biao" => 119, "force" => 150}})

      assert {:error, "你的八卦镖还练得不到家，自己下去练练再来吧！\n"} =
               SectMaster.inquiry_grant(biao_low, npc_stats(npc), cfg)

      # 内功不足（force 149）→ 内功文案（最后一关）
      force_low =
        disciple(%{base | skills: %{"bagua-zhang" => 120, "bagua-biao" => 120, "force" => 149}})

      assert {:error, "嗯，你的镖掌都已经娴熟了，但是切记内功火候是基础，这可半点马虎不得。\n"} =
               SectMaster.inquiry_grant(force_low, npc_stats(npc), cfg)
    end
  end

  # ---------------------------------------------------------------------------
  # 天地会（yunlong / 云龙门）—— Task #619 本批
  # LPC: kungfu/class/yunlong/{chen,ma,xuanzhen}.c + yunlong.h + tiandihui.h
  # ---------------------------------------------------------------------------
  describe "天地会 UCL 数据回填（Task #619）" do
    defp yl(world, name, room) do
      npc = npc(world, name, room)
      assert npc, "#{name} 应随世界加载（#{room}）"
      npc
    end

    test "三名天地会 NPC 的 teach 落位；陈近南 不带 family", %{world: world} do
      # 陈近南：11 技能；teach 无 family（疾电门控不含门派校验，见计划 §2.3）
      chen = yl(world, "陈近南", "beijing:qingmu_dating")
      assert chen.meta.teach

      assert chen.meta.teach.family == nil,
             "陈近南 teach 不应带 family（LPC ask_me 无 family 门）"

      assert map_size(chen.meta.teach.teach_skills) == 11
      assert chen.meta.teach.teach_skills["ningxue-shenzhao"].max == 250

      # 马超兴：13 技能，family = 云龙门
      ma = yl(world, "马超兴", "city:beimen")
      assert ma.meta.teach.family == "云龙门"
      assert map_size(ma.meta.teach.teach_skills) == 13

      # 玄贞道长：15 技能（beijing.ucl 置其于 qingmu_dayuan 大院）
      xz = yl(world, "玄贞道长", "beijing:qingmu_dayuan")
      assert xz.meta.teach.family == "云龙门"
      assert map_size(xz.meta.teach.teach_skills) == 15
    end

    test "三名 NPC 全部 deny_all 拒收（yunlong.h permit_recruit 直接 return 0）", %{
      world: world
    } do
      for {name, room} <- [
            {"陈近南", "beijing:qingmu_dating"},
            {"马超兴", "city:beimen"},
            {"玄贞道长", "beijing:qingmu_dayuan"}
          ] do
        a = yl(world, name, room).meta.apprentice
        assert a.deny_all == true, "#{name} 应拒收"
        assert a.deny_msg == "对不起，我云龙门不对外收徒。", name
      end
    end

    test "陈近南 4 键 ask_me 同闭包：疾电授艺 + shen 下限 + 凝血神爪 250", %{
      world: world
    } do
      npc = yl(world, "陈近南", "beijing:qingmu_dating")

      for key <- ["绝技", "绝招", "疾电", "凝血神爪"] do
        cfg = inquiry(npc, key)
        assert cfg["kind"] == "sect_master_grant", key
        assert cfg["perform_id"] == "ningxue-shenzhao/ji", key
        assert cfg["skill"] == "ningxue-shenzhao", key
        assert cfg["gate_order"] == "lpc_kunlun", key
        # LPC `shen < 1000000` → 「侠」字文案
        assert cfg["min_shen"] == 1_000_000, key
        assert cfg["shen_deny"] == "习武之人最重一个“侠”字，侠义方面你还做得不够！", key
        # LPC 末条 `query_skill("ningxue-shenzhao", 1) < 250`
        assert cfg["min_perform_skill"] == "ningxue-shenzhao", key
        assert cfg["min_levels"] == %{"ningxue-shenzhao" => 250}, key
        assert cfg["level_deny"]["ningxue-shenzhao"] == "你的凝血神爪还不到家，要多练练！", key
        assert cfg["maxed"] == "你真会开玩笑，会了还来找我。", key
        assert cfg["learned"] == "你学会了「疾电」这一招。", key
        assert cfg["improve_skills"] == ["claw"], key
        # 疾电无贡献门槛（LPC 不判 gongxian）
        refute Map.has_key?(cfg, "min_gongxian"), key
        refute Map.has_key?(cfg, "cost_gongxian"), key
      end

      # 2 条纯文本直答 + 2 条退会说明
      assert inquiry(npc, "天地会") =~ "join tiandihui"
      assert inquiry(npc, "入会") == "还不快快如天地会一同反清复明。"
      assert inquiry(npc, "退会") =~ "GAP"
      assert inquiry(npc, "tuihui") =~ "GAP"
    end

    test "门控联验：陈近南 疾电 按 LPC 顺序（shen → 凝血神爪 → 过门）", %{
      world: world
    } do
      npc = yl(world, "陈近南", "beijing:qingmu_dating")
      cfg = inquiry(npc, "疾电")

      # 无 family 门：外派玩家（family 非云龙门）同样只按 shen/技能判定
      base = %{
        family: nil,
        shen: 1_000_000,
        gongxian: 0,
        performs: MapSet.new(),
        skills: %{"ningxue-shenzhao" => 250}
      }

      assert {:ok, "ningxue-shenzhao/ji", 0} =
               SectMaster.inquiry_grant(disciple(base), npc_stats(npc), cfg)

      # 侠义不足（shen 0）→ shen_deny
      low_shen = disciple(%{base | shen: 0})

      assert {:error, "习武之人最重一个“侠”字，侠义方面你还做得不够！\n"} =
               SectMaster.inquiry_grant(low_shen, npc_stats(npc), cfg)

      # 凝血神爪 249 → 「还不到家」（min_perform_skill 门）
      low_skill = disciple(%{base | skills: %{"ningxue-shenzhao" => 249}})

      assert {:error, "你的凝血神爪还不到家，要多练练！"} =
               SectMaster.inquiry_grant(low_skill, npc_stats(npc), cfg)

      # 完全未学 → skill_deny
      no_skill = disciple(%{base | skills: %{}})

      assert {:error, "你连这门功夫都没学，还谈什么绝招可言？\n"} =
               SectMaster.inquiry_grant(no_skill, npc_stats(npc), cfg)

      # 已学会 → maxed
      known = disciple(%{base | performs: MapSet.new(["ningxue-shenzhao/ji"])})
      assert {:error, "你真会开玩笑，会了还来找我。\n"} = SectMaster.inquiry_grant(known, npc_stats(npc), cfg)
    end

    test "天地会 4 条 join 说明文案落位（tiandihui.h do_join 为死代码 → GAP）", %{
      world: world
    } do
      # LPC tiandihui.h 的 do_join 首行即 notify_fail，永不可达 → 无「入会」可移植逻辑
      chen = yl(world, "陈近南", "beijing:qingmu_dating")
      assert is_map(chen.meta.inquiries)
      assert chen.meta.inquiries["退会"] =~ "GAP"
    end
  end

  # ---------------------------------------------------------------------------
  # 大理段氏（duan / 段氏皇族）—— Task #838-#842 本批
  # LPC: kungfu/class/duan/{duan.h,*.c}（14 NPC / 14 ask_skill / 11 permit_recruit）
  # ---------------------------------------------------------------------------

  describe "大理段氏 UCL 数据回填（Task #840）" do
    defp dm(world, name, room) do
      npc = npc(world, name, room)
      assert npc, "#{name} 应随世界加载（#{room}）"
      npc
    end

    test "14 名段氏 NPC 的 teach 全覆盖；11 名收徒门控逐字落位", %{world: world} do
      for {name, room, skill_count, recruit?} <- [
            {"巴天石", "dali:sikong", 13, true},
            {"褚万里", "dali:wangfugate", 13, true},
            {"刀白凤", "dali:yuxuguan", 19, true},
            {"段延庆", "wanjiegu:backyard", 18, false},
            {"段誉", "xiaoyao:qingcaop", 13, false},
            {"段正淳", "dali:neitang", 18, true},
            {"段正明", "dali:qiandian", 20, true},
            {"范骅", "dali:sima", 13, true},
            {"傅思归", "dali:wangfulu", 13, true},
            {"高升泰", "dali:louti", 13, true},
            {"古笃诚", "dali:tingfang", 13, true},
            {"华赫艮", "dali:situ", 13, true},
            {"一灯大师", "dali:qingchi", 22, false},
            {"朱丹臣", "dali:shufang", 13, true}
          ] do
        npc = dm(world, name, room)

        assert npc.meta.teach, "#{name} 应有 teach"
        assert npc.meta.teach.family == "段氏皇族", "#{name} teach.family"

        assert map_size(npc.meta.teach.teach_skills) == skill_count,
               "#{name} teach_skills 应为 #{skill_count} 项，实际 #{map_size(npc.meta.teach.teach_skills)}"

        if recruit? do
          gate = npc.meta.apprentice
          assert gate, "#{name} 应有 apprentice"
          assert gate.family == "段氏皇族", "#{name} apprentice.family"
          assert gate.permit_recruit == true, "#{name} permit_recruit"
          # duan.h permit_recruit 三句逐字覆写
          assert gate.betray_sect_deny == "既然离开了我们段家，就不要回来了"
          assert gate.betray_times_deny == "哼，我们大理段氏最痛恨的就是不忠不义之徒。"
          assert gate.other_family_deny == "你当年跑出去的时候怎么就没想过要回来？"
        else
          # yideng.c / duanyq.c / duanyu.c 无 attempt_apprentice
          assert is_nil(npc.meta.apprentice), "#{name} 不应收徒"
        end
      end
    end

    test "14 名 NPC combat 块完整（防 inquiry 回填误删战斗属性）", %{world: world} do
      # 历史教训：王剑杰/王维扬 combat 块曾在 inquiry 回填时被误删且测试未覆盖；
      # 这里把段氏 14 NPC 的 combat_exp/max_neili/max_qi/max_jing 全部锁住。
      for {name, room, exp, neili, qi, jing} <- [
            {"巴天石", "dali:sikong", 1_500_000, 3200, 3000, 1800},
            {"褚万里", "dali:wangfugate", 500_000, 2200, 1800, 1000},
            {"刀白凤", "dali:yuxuguan", 800_000, 3000, 2500, 1200},
            {"段延庆", "wanjiegu:backyard", 3_000_000, 7000, 6000, 4000},
            {"段誉", "xiaoyao:qingcaop", 1_500_000, 9000, 5000, 2500},
            {"段正淳", "dali:neitang", 2_500_000, 5800, 4500, 3000},
            {"段正明", "dali:qiandian", 3_000_000, 7000, 6000, 4000},
            {"范骅", "dali:sima", 1_500_000, 3200, 3000, 1800},
            {"傅思归", "dali:wangfulu", 500_000, 2200, 1800, 1000},
            {"高升泰", "dali:louti", 2_500_000, 5800, 4500, 3000},
            {"古笃诚", "dali:tingfang", 500_000, 2200, 1800, 1000},
            {"华赫艮", "dali:situ", 1_500_000, 3200, 3000, 1800},
            {"一灯大师", "dali:qingchi", 4_000_000, 8000, 6500, 5000},
            {"朱丹臣", "dali:shufang", 500_000, 2200, 1800, 1000}
          ] do
        npc = dm(world, name, room)

        assert npc.meta.stats.combat_exp == exp, "#{name} combat_exp"
        assert npc.meta.vitals.max_neili == neili, "#{name} max_neili"
        assert npc.meta.vitals.max_qi == qi, "#{name} max_qi"
        assert npc.meta.vitals.max_jing == jing, "#{name} max_jing"
      end
    end

    test "14 条 sect_master_grant：perform_id / 门控字段 / gate_order 与 LPC 一致", %{
      world: world
    } do
      # 元组：NPC / 房间 / 问询键 / perform_id / gate_order / min_gongxian / cost /
      #      min_shen（nil = LPC 无此门）/ level_order / min_levels（loader 已归一 `_`→`-`）
      for {name, room, key, perform_id, gate, gongxian, cost, shen, order, levels} <- [
            {
              "一灯大师",
              "dali:qingchi",
              "先天功乾阳剑气",
              "xiantian-gong/jian",
              "lpc_kunlun",
              3000,
              3000,
              50_000,
              ["force", "max-neili", "xiantian-gong", "yiyang-zhi", "jingluo-xue"],
              %{
                "force" => 500,
                "max-neili" => 5000,
                "xiantian-gong" => 280,
                "yiyang-zhi" => 280,
                "jingluo-xue" => 200
              }
            },
            {
              "一灯大师",
              "dali:qingchi",
              "阳关三叠",
              "yiyang-zhi/die",
              "lpc_duan",
              2500,
              2500,
              50_000,
              ["force", "max-neili", "jingluo-xue", "yiyang-zhi"],
              %{
                "force" => 300,
                "max-neili" => 5000,
                "jingluo-xue" => 200,
                "yiyang-zhi" => 200
              }
            },
            {
              "段正淳",
              "dali:neitang",
              "乾阳神指",
              "qiantian-zhi/zhi",
              "lpc_kunlun",
              50,
              50,
              nil,
              ["force", "max-neili", "qiantian-zhi"],
              %{"force" => 100, "max-neili" => 500, "qiantian-zhi" => 80}
            },
            {
              "段正淳",
              "dali:neitang",
              "惊天一剑",
              "duanjia-jian/jing",
              "lpc_duan",
              300,
              300,
              0,
              ["force", "max-neili", "duanjia-jian"],
              %{"force" => 120, "max-neili" => 800, "duanjia-jian" => 80}
            },
            {
              "段正淳",
              "dali:neitang",
              "金玉满堂",
              "jinyu-quan/man",
              "lpc_kunlun",
              150,
              150,
              nil,
              ["force", "max-neili", "jinyu-quan"],
              %{"force" => 100, "max-neili" => 500, "jinyu-quan" => 80}
            },
            {
              "段正淳",
              "dali:neitang",
              "风云变幻",
              "wuluo-zhang/bian",
              "lpc_kunlun",
              150,
              150,
              nil,
              ["force", "max-neili", "wuluo-zhang"],
              %{"force" => 100, "max-neili" => 500, "wuluo-zhang" => 100}
            },
            {
              "段正明",
              "dali:qiandian",
              "一指乾坤",
              "yiyang-zhi/qian",
              "lpc_duan",
              1000,
              1000,
              30_000,
              ["force", "max-neili", "jingluo-xue", "yiyang-zhi"],
              %{
                "force" => 220,
                "max-neili" => 2400,
                "jingluo-xue" => 160,
                "yiyang-zhi" => 160
              }
            },
            {
              "段正明",
              "dali:qiandian",
              "五绝连环",
              "duanjia-jian/lian",
              "lpc_duan",
              400,
              400,
              0,
              ["force", "duanjia-jian"],
              %{"force" => 160, "duanjia-jian" => 120}
            },
            {
              "段正明",
              "dali:qiandian",
              "神指点穴",
              "yiyang-zhi/dian",
              "lpc_duan",
              400,
              400,
              20_000,
              ["force", "max-neili", "jingluo-xue", "yiyang-zhi"],
              %{
                "force" => 160,
                "max-neili" => 1800,
                "jingluo-xue" => 120,
                "yiyang-zhi" => 120
              }
            },
            {
              "段正明",
              "dali:qiandian",
              "起死回生",
              "yiyang-zhi/heal",
              "lpc_kunlun",
              800,
              800,
              nil,
              ["force", "max-neili", "jingluo-xue", "yiyang-zhi"],
              %{
                "force" => 150,
                "max-neili" => 1500,
                "jingluo-xue" => 100,
                "yiyang-zhi" => 100
              }
            },
            {
              "刀白凤",
              "dali:yuxuguan",
              "凤栖于梧",
              "feifeng-bian/xi",
              "lpc_kunlun",
              300,
              300,
              0,
              ["force", "max-neili", "feifeng-bian"],
              %{"force" => 150, "max-neili" => 1200, "feifeng-bian" => 120}
            },
            {
              "古笃诚",
              "dali:tingfang",
              "错字诀",
              "pangen-cuojiefu/cuo",
              "lpc_kunlun",
              150,
              150,
              nil,
              ["force", "max-neili", "pangen-cuojiefu"],
              %{"force" => 120, "max-neili" => 800, "pangen-cuojiefu" => 100}
            },
            {
              "华赫艮",
              "dali:situ",
              "弑元诀",
              "yuezhao-gong/shi",
              "lpc_kunlun",
              400,
              400,
              nil,
              ["force", "max-neili", "yuezhao-gong"],
              %{"force" => 200, "max-neili" => 1800, "yuezhao-gong" => 130}
            },
            {
              "朱丹臣",
              "dali:shufang",
              "透骨钉",
              "qingliang-daxuefa/ding",
              "lpc_kunlun",
              400,
              400,
              nil,
              ["force", "max-neili", "qingliang-daxuefa"],
              %{"force" => 150, "max-neili" => 1200, "qingliang-daxuefa" => 100}
            }
          ] do
        cfg = inquiry(dm(world, name, room), key)

        assert cfg, "#{name} 应能回答「#{key}」"
        assert cfg["kind"] == "sect_master_grant"
        assert cfg["perform_id"] == perform_id
        assert cfg["skill"] == hd(String.split(perform_id, "/"))
        assert cfg["family"] == "段氏皇族"
        assert cfg["gate_order"] == gate, "#{key} gate_order"
        assert cfg["min_gongxian"] == gongxian, "#{key} min_gongxian"
        assert cfg["cost_gongxian"] == cost, "#{key} cost_gongxian"
        assert cfg["min_shen"] == shen, "#{key} min_shen"
        assert cfg["level_order"] == order, "#{key} level_order"
        assert cfg["min_levels"] == levels, "#{key} min_levels"
        assert is_binary(cfg["maxed"]) and byte_size(cfg["maxed"]) > 0
        assert is_binary(cfg["skill_deny"]) and byte_size(cfg["skill_deny"]) > 0
        assert is_binary(cfg["gongxian_deny"]) and byte_size(cfg["gongxian_deny"]) > 0
        assert is_binary(cfg["learned"]) and byte_size(cfg["learned"]) > 0
        assert is_list(cfg["improve_skills"]) and cfg["improve_skills"] != []
      end

      # 段氏的负神门（shen < 0）逐句使用 LPC 原文，不得被通用文案覆盖
      assert inquiry(dm(world, "段正淳", "dali:neitang"), "惊天一剑")["shen_deny"] ==
               "算了吧，传你绝招只怕你又去作恶！"

      assert inquiry(dm(world, "刀白凤", "dali:yuxuguan"), "凤栖于梧")["shen_deny"] ==
               "哼，你还嫌你在外面惹的祸事不够么？"

      # 带动态敬称前缀的 family_deny 保留 LPC 原文尾句（#830/#832 同类约定）
      assert inquiry(dm(world, "古笃诚", "dali:tingfang"), "错字诀")["family_deny"] ==
               "和古某素不相识，何出此言？"

      for {name, room, key} <- [
            {"华赫艮", "dali:situ", "弑元诀"},
            {"朱丹臣", "dali:shufang", "透骨钉"},
            {"刀白凤", "dali:yuxuguan", "凤栖于梧"}
          ] do
        assert inquiry(dm(world, name, room), key)["family_deny"] ==
                 "和我素无瓜葛，何出此言？"
      end

      # 段正明两本脉经为多状态 give_item 缺口，保留 GAP 文本而非伪造简化逻辑
      zm = dm(world, "段正明", "dali:qiandian")
      assert zm.meta.inquiries["王叔和脉经"] =~ "GAP #844"
      assert zm.meta.inquiries["玉颧神脉经"] =~ "GAP #844"

      # 全部段氏角色的 "inquire about skillN (unimplemented)" 占位清零
      duan_names = [
        "巴天石",
        "褚万里",
        "刀白凤",
        "段延庆",
        "段誉",
        "段正淳",
        "段正明",
        "范骅",
        "傅思归",
        "高升泰",
        "古笃诚",
        "华赫艮",
        "一灯大师",
        "朱丹臣"
      ]

      for npc <- world.characters, npc.name in duan_names do
        if is_binary(npc.meta.inquiries) do
          refute String.contains?(npc.meta.inquiries, "unimplemented"),
                 "#{npc.name} 仍保留未实现问询占位"
        end

        if is_map(npc.meta.inquiries) do
          refute Enum.any?(npc.meta.inquiries, fn {_k, v} ->
                   is_binary(v) and String.contains?(v, "unimplemented")
                 end),
                 "#{npc.name} 仍保留未实现问询占位"
        end
      end
    end

    test "门控联验：「神指点穴」走 lpc_duan（贡献先于侠义），逐条命中 LPC 文案", %{
      world: world
    } do
      cfg = inquiry(dm(world, "段正明", "dali:qiandian"), "神指点穴")

      base =
        disciple(%{
          family: "段氏皇族",
          gongxian: 400,
          shen: 20_000,
          max_neili: 1800,
          skills: %{
            "force" => 160,
            "jingluo-xue" => 120,
            "yiyang-zhi" => 120
          }
        })

      assert {:ok, "yiyang-zhi/dian", 400} =
               SectMaster.inquiry_grant(base, npc_stats(dm(world, "段正明", "dali:qiandian")), cfg)

      # 已学会 → maxed
      known = %{base | performs: MapSet.new(["yiyang-zhi/dian"])}

      assert {:error, text} =
               SectMaster.inquiry_grant(known, npc_stats(dm(world, "段正明", "dali:qiandian")), cfg)

      assert text =~ "你不是已经学会了么？"

      # 外派 → family_deny
      outsider = %{base | family: "大理段氏"}

      assert {:error, text} =
               SectMaster.inquiry_grant(
                 outsider,
                 npc_stats(dm(world, "段正明", "dali:qiandian")),
                 cfg
               )

      assert text =~ "你又不是我们段家的传人"

      # 未学一阳指 → skill_deny
      no_skill = %{base | skills: %{}}

      assert {:error, text} =
               SectMaster.inquiry_grant(
                 no_skill,
                 npc_stats(dm(world, "段正明", "dali:qiandian")),
                 cfg
               )

      assert text =~ "你连一阳指诀都没学"

      # 贡献不足 + 侠义也不足 → 必须是「贡献」先拦（lpc_duan 的关键差异）
      low_both = %{base | gongxian: 399, shen: 0}

      assert {:error, text} =
               SectMaster.inquiry_grant(
                 low_both,
                 npc_stats(dm(world, "段正明", "dali:qiandian")),
                 cfg
               )

      assert text =~ "你在族里碌碌无为"

      # 贡献够、侠义不足 → shen_deny
      low_shen = %{base | shen: 19_999}

      assert {:error, text} =
               SectMaster.inquiry_grant(
                 low_shen,
                 npc_stats(dm(world, "段正明", "dali:qiandian")),
                 cfg
               )

      assert text =~ "你侠义正事做得不够"

      # 四项等级门槛按 LPC 顺序逐条命中
      for {skill, text} <- [
            {"force", "你内功的修为还不够"},
            {"max-neili", "你的内力修为还不够"},
            {"jingluo-xue", "你对经络学的了解还不透彻"},
            {"yiyang-zhi", "你的一阳指诀功力还不够"}
          ] do
        weak =
          case skill do
            "max-neili" ->
              %{base | max_neili: 1799}

            key ->
              skills = base.skills
              low = Map.get(skills, key) - 1
              %{base | skills: Map.put(skills, key, low)}
          end

        assert {:error, deny} =
                 SectMaster.inquiry_grant(weak, npc_stats(dm(world, "段正明", "dali:qiandian")), cfg)

        assert deny =~ text, "#{skill} 应命中对应文案，实际 #{deny}"
      end
    end

    test "段正明收徒门：lpc_xuanming 顺序（shen → duanshi-xinfa → exp）与逐字文案", %{
      world: world
    } do
      gate = dm(world, "段正明", "dali:qiandian").meta.apprentice

      assert gate.gate_order == "lpc_xuanming"
      assert gate.min_shen == 50_000
      assert gate.min_shen_deny == "你江湖上的名声不怎么样，这样的人如何能够治好国家？"
      assert gate.min_skills == %{"duanshi-xinfa" => 100}
      assert gate.min_exp == 400_000
      assert gate.min_exp_deny == "你实战经验太低，应好好在江湖上历炼，不要失了段氏的面子。"

      student = %{
        meta: %{
          family: %{name: "段氏皇族"},
          stats: %{
            shen: 50_000,
            combat_exp: 400_000,
            skills: %{"duanshi-xinfa" => 100}
          }
        }
      }

      assert :ok = SectMaster.recruit_gate?(nil, student, gate)

      low_shen = put_in(student, [:meta, :stats, :shen], 49_999)
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_shen, gate)
      assert reason =~ "治好国家"

      low_skill = put_in(student, [:meta, :stats, :skills], %{"duanshi-xinfa" => 99})

      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_skill, gate)
      assert reason =~ "你先好好学习我们段家的心法"

      low_exp = put_in(student, [:meta, :stats, :combat_exp], 399_999)
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_exp, gate)
      assert reason =~ "段氏的面子"
    end
  end

  # ---------------------------------------------------------------------------
  # 峨眉派（emei / 峨嵋派）—— Task #847-#851 本批
  # LPC: kungfu/class/emei/{emei.h,tobebonze.h,*.c}（28 个 .c，25 个已在 ex）
  # ---------------------------------------------------------------------------

  describe "峨眉派 UCL 数据回填（Task #849）" do
    defp em(world, name, room) do
      npc = npc(world, name, room)
      assert npc, "#{name} 应随世界加载（#{room}）"
      npc
    end

    test "24 名 emei NPC 的 teach/no_teach/apprentice 与 LPC 一致（含 #691 旧块修正）", %{
      world: world
    } do
      # 元组：NPC / 房间 / teach_skills 项数 / no_teach 项数 / 收徒 / bonze 师父
      for {name, room, skills, no_teach_count, recruit?, bonze?} <- [
            {"贝锦仪", "emei:duguangtai", 15, 0, true, false},
            {"静道师太", "emei:cangjingge", 15, 0, true, true},
            {"方碧琳", "emei:yunufeng", 14, 0, true, false},
            {"静风师太", "emei:chuwujian", 15, 0, true, true},
            {"风陵师太", "emei:jinding", 23, 1, true, true},
            {"静和师太", "emei:hcaeast", 20, 1, true, true},
            {"静慧师太", "emei:qfadadian", 20, 1, true, true},
            {"静迦师太", "emei:wanxingan", 20, 1, true, true},
            {"静空师太", "emei:wnadian", 20, 1, true, true},
            {"李明霞", "emei:huayanding", 15, 0, true, false},
            {"赵灵珠", "emei:lianhuashi", 15, 0, true, false},
            {"灭绝师太", "emei:hcahoudian", 24, 1, true, true},
            {"苏梦清", "emei:lianhuashi", 15, 0, true, false},
            {"文方小师太", "emei:wnadian", 4, 0, false, false},
            {"文晖小师太", "emei:hcaeast", 4, 0, false, false},
            {"文清小师太", "emei:hcawest", 4, 0, false, false},
            {"文音小师太", "emei:qfadadian", 4, 0, false, false},
            {"静闲师太", "emei:qingyinge", 20, 1, true, true},
            {"静心师太", "emei:hcazhengdian", 20, 1, true, true},
            {"静虚师太", "emei:hcaguangchang", 20, 1, true, true},
            {"静玄师太", "emei:woyunan", 20, 1, true, true},
            {"静照师太", "emei:lingwenge", 20, 1, true, true},
            {"静真师太", "emei:fushouan", 20, 1, true, true},
            {"周芷若", "emei:qinggong", 23, 6, true, false}
          ] do
        npc = em(world, name, room)
        teach = npc.meta.teach

        assert teach, "#{name} 应有 teach"
        assert teach.family == "峨嵋派", "#{name} teach.family"

        assert map_size(teach.teach_skills) == skills,
               "#{name} teach_skills 应为 #{skills}，实际 #{map_size(teach.teach_skills)}"

        assert length(teach.no_teach) == no_teach_count, "#{name} no_teach"

        if recruit? do
          gate = npc.meta.apprentice
          assert gate, "#{name} 应有 apprentice"
          assert gate.family == "峨嵋派"
          assert gate.gender == "女性", "#{name} 峨嵋派不收男弟子"
          assert gate.gate_order == "gender_first", "#{name} 性别门先于 permit_recruit"
          assert gate.permit_recruit == true
          assert gate.betray_sect_deny == "你当年既然离开了峨嵋派，今天又何必回来？"
          assert gate.betray_times_deny == "你欺师灭主，背叛师门，这种人我们峨嵋派不会收留的。"

          if bonze? do
            assert gate.require_class == "bonze", "#{name} bonze 师父不收俗家弟子"
            assert gate.class_deny == "阿弥陀佛！贫尼不收俗家弟子。"
          else
            assert is_nil(gate.require_class), "#{name} 非 bonze 师父"
          end
        else
          assert is_nil(npc.meta.apprentice), "#{name} 无 attempt_apprentice"
        end
      end

      # #691 旧块曾编造 max=60 / gongxian=2|3：现已按 LPC set_skill 原值重写
      miejue = em(world, "灭绝师太", "emei:hcahoudian")
      assert miejue.meta.teach.teach_skills["linji-zhuang"].max == 260
      assert miejue.meta.teach.teach_skills["linji-zhuang"].gongxian == 0
      assert miejue.meta.teach.teach_skills["emei-xinfa"].max == 260
      assert map_size(miejue.meta.teach.teach_skills) == 24
      assert "emei-jiuyang" in miejue.meta.teach.no_teach

      # 周芷若 6 项 no_teach 逐技能文案
      zhou = em(world, "周芷若", "emei:qinggong")

      assert Enum.sort(zhou.meta.teach.no_teach) ==
               Enum.sort([
                 "yinlong-bian",
                 "jiuyin-baiguzhao",
                 "cuixin-zhang",
                 "yijin-duangu",
                 "shexing-lifan",
                 "linji-zhuang"
               ])

      assert zhou.meta.teach.no_teach_deny["linji-zhuang"] == "想学临济十二庄找我师父去。"
    end

    test "24 名 emei NPC combat 块完整（防 inquiry 回填误删战斗属性）", %{world: world} do
      for {name, room, exp, neili, qi, jing} <- [
            {"贝锦仪", "emei:duguangtai", 250_000, 2500, 2100, 1000},
            {"静道师太", "emei:cangjingge", 180_000, 2500, 2300, 1200},
            {"方碧琳", "emei:yunufeng", 70_000, 1500, 1200, 600},
            {"静风师太", "emei:chuwujian", 250_000, 2400, 1800, 900},
            {"风陵师太", "emei:jinding", 5_000_000, 8000, 7000, 6000},
            {"静和师太", "emei:hcaeast", 800_000, 2700, 2200, 1100},
            {"静慧师太", "emei:qfadadian", 800_000, 3300, 3100, 1600},
            {"静迦师太", "emei:wanxingan", 800_000, 3300, 3000, 1500},
            {"静空师太", "emei:wnadian", 800_000, 2900, 2800, 500},
            {"李明霞", "emei:huayanding", 90_000, 1800, 1600, 800},
            {"赵灵珠", "emei:lianhuashi", 250_000, 2500, 2100, 1000},
            {"灭绝师太", "emei:hcahoudian", 2_500_000, 6000, 4500, 3000},
            {"苏梦清", "emei:lianhuashi", 250_000, 2500, 2100, 1000},
            {"文方小师太", "emei:wnadian", 2_000, 150, 150, 100},
            {"文晖小师太", "emei:hcaeast", 2_000, 150, 150, 100},
            {"文清小师太", "emei:hcawest", 2_000, 150, 150, 100},
            {"文音小师太", "emei:qfadadian", 2_000, 150, 150, 100},
            {"静闲师太", "emei:qingyinge", 800_000, 3300, 3100, 1600},
            {"静心师太", "emei:hcazhengdian", 130_000, 5000, 5000, 3000},
            {"静虚师太", "emei:hcaguangchang", 800_000, 3300, 3100, 1600},
            {"静玄师太", "emei:woyunan", 800_000, 3300, 3100, 1600},
            {"静照师太", "emei:lingwenge", 110_000, 2500, 2100, 1000},
            {"静真师太", "emei:fushouan", 110_000, 2500, 2100, 1000},
            {"周芷若", "emei:qinggong", 2_500_000, 6000, 5000, 3000}
          ] do
        npc = em(world, name, room)
        assert npc.meta.stats.combat_exp == exp, "#{name} combat_exp"
        assert npc.meta.vitals.max_neili == neili, "#{name} max_neili"
        assert npc.meta.vitals.max_qi == qi, "#{name} max_qi"
        assert npc.meta.vitals.max_jing == jing, "#{name} max_jing"
      end
    end

    test "11 条 sect_master_grant：perform_id / 门控字段 / lpc_emei 与 LPC 一致", %{
      world: world
    } do
      # 元组：NPC / 房间 / 键 / perform_id / 贡献 / shen / level_order / min_levels / improve
      for {name, room, key, perform, gx, shen, order, levels, improve} <- [
            {
              "灭绝师太",
              "emei:hcahoudian",
              "灭剑",
              "huifeng-jian/mie",
              1000,
              30_000,
              ["force", "huifeng-jian"],
              %{"force" => 180, "huifeng-jian" => 120},
              ["sword", "sword", "huifeng-jian", "huifeng-jian", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "绝剑",
              "huifeng-jian/jue",
              1800,
              30_000,
              ["force", "huifeng-jian"],
              %{"force" => 300, "huifeng-jian" => 180},
              ["sword", "sword", "huifeng-jian", "huifeng-jian", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "星罗棋布",
              "sixiang-zhang/xing",
              80,
              5_000,
              ["force", "sixiang-zhang"],
              %{"force" => 100, "sixiang-zhang" => 70},
              ["strike", "strike", "sixiang-zhang", "sixiang-zhang", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "八式合一",
              "jinding-zhang/bashi",
              250,
              8_000,
              ["force", "jinding-zhang"],
              %{"force" => 120, "jinding-zhang" => 100},
              ["strike", "strike", "jinding-zhang", "jinding-zhang", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "截筋断脉",
              "jieshou-jiushi/jie",
              300,
              12_000,
              ["max-neili", "force", "jieshou-jiushi"],
              %{"max-neili" => 850, "force" => 120, "jieshou-jiushi" => 100},
              ["hand", "hand", "jieshou-jiushi", "jieshou-jiushi", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "凌空指穴",
              "tiangang-zhi/ling",
              250,
              10_000,
              ["max-neili", "force", "tiangang-zhi"],
              %{"max-neili" => 800, "force" => 100, "tiangang-zhi" => 100},
              ["finger", "finger", "tiangang-zhi", "tiangang-zhi", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "无形幻影",
              "yanxing-dao/huan",
              300,
              15_000,
              ["max-neili", "force", "yanxing-dao"],
              %{"max-neili" => 800, "force" => 120, "yanxing-dao" => 80},
              ["blade", "blade", "yanxing-dao", "yanxing-dao", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "佛光初现",
              "emei-jian/xian",
              50,
              3_000,
              ["force", "emei-jian"],
              %{"force" => 80, "emei-jian" => 60},
              ["sword", "sword", "emei-jian", "emei-jian", "martial-cognize"]
            },
            {
              "灭绝师太",
              "emei:hcahoudian",
              "伏魔剑诀",
              "yitian-jian/fumo",
              500,
              20_000,
              ["force", "yitian-jian"],
              %{"force" => 180, "yitian-jian" => 120},
              ["sword", "sword", "yitian-jian", "yitian-jian", "martial-cognize"]
            },
            {
              "风陵师太",
              "emei:jinding",
              "云海明灯",
              "piaoxue-zhang/yun",
              1800,
              40_000,
              ["force", "max-neili", "piaoxue-zhang"],
              %{"force" => 200, "max-neili" => 2000, "piaoxue-zhang" => 150},
              ["strike", "strike", "piaoxue-zhang", "piaoxue-zhang", "martial-cognize"]
            },
            {
              "风陵师太",
              "emei:jinding",
              "佛光普照",
              "piaoxue-zhang/zhao",
              2200,
              40_000,
              ["force", "max-neili", "piaoxue-zhang"],
              %{"force" => 300, "max-neili" => 3500, "piaoxue-zhang" => 180},
              ["strike", "strike", "piaoxue-zhang", "piaoxue-zhang", "martial-cognize"]
            }
          ] do
        cfg = inquiry(em(world, name, room), key)

        assert cfg, "#{name} 应能回答「#{key}」"
        assert cfg["kind"] == "sect_master_grant"
        assert cfg["perform_id"] == perform
        assert cfg["skill"] == hd(String.split(perform, "/"))
        assert cfg["family"] == "峨嵋派"
        assert cfg["gate_order"] == "lpc_emei", "#{key} 须走 LPC「shen 在最后」路径"
        assert cfg["min_gongxian"] == gx, "#{key} 贡献门"
        assert cfg["cost_gongxian"] == gx, "#{key} 扣除贡献"
        assert cfg["min_shen"] == shen, "#{key} 侠义门"
        assert cfg["level_order"] == order, "#{key} 等级链顺序"
        assert cfg["min_levels"] == levels, "#{key} 等级链阈值"
        assert cfg["improve_skills"] == improve, "#{key} LPC improve_skill 次数"
        assert is_binary(cfg["maxed"]) and is_binary(cfg["skill_deny"])
        assert is_binary(cfg["gongxian_deny"]) and is_binary(cfg["shen_deny"])
        assert is_binary(cfg["learned"])
      end

      # 逐字文案抽样（生成器最易在动态敬称前缀处失真）
      assert inquiry(em(world, "灭绝师太", "emei:hcahoudian"), "灭剑")["family_deny"] ==
               "你是哪里来的？快给我滚开！"

      assert inquiry(em(world, "灭绝师太", "emei:hcahoudian"), "截筋断脉")["gongxian_deny"] ==
               "哼，你在本派中碌碌无为，这一招我暂时还不能传你。"

      assert inquiry(em(world, "风陵师太", "emei:jinding"), "佛光普照")["shen_deny"] ==
               "你行侠仗义的事情还做得不够，我暂时还不能传你此招。"

      # 风陵直传弟子门（master_id）明确登记 GAP #852，不得伪装成普通同门门
      fl = inquiry(em(world, "风陵师太", "emei:jinding"), "云海明灯")
      refute Map.has_key?(fl, "require_master_id")
    end

    test "状态类问询保留 GAP 标记，34 处 unimplemented 占位清零", %{world: world} do
      emei_names = [
        "贝锦仪",
        "静道师太",
        "方碧琳",
        "静风师太",
        "风陵师太",
        "静和师太",
        "静慧师太",
        "静迦师太",
        "静空师太",
        "李明霞",
        "赵灵珠",
        "灭绝师太",
        "苏梦清",
        "文方小师太",
        "文晖小师太",
        "文清小师太",
        "文音小师太",
        "静闲师太",
        "静心师太",
        "静虚师太",
        "静玄师太",
        "静照师太",
        "静真师太",
        "周芷若"
      ]

      for npc <- world.characters, npc.name in emei_names do
        if is_map(npc.meta.inquiries) do
          refute Enum.any?(npc.meta.inquiries, fn {_k, v} ->
                   is_binary(v) and String.contains?(v, "unimplemented")
                 end),
                 "#{npc.name} 仍有未实现问询占位"
        end
      end

      assert em(world, "静慧师太", "emei:qfadadian").meta.inquiries["剃度"] =~ "GAP #853"
      assert em(world, "灭绝师太", "emei:hcahoudian").meta.inquiries["还俗"] =~ "GAP #857"
      assert em(world, "静风师太", "emei:chuwujian").meta.inquiries["伤药"] =~ "GAP #854"
      assert em(world, "李明霞", "emei:huayanding").meta.inquiries["back"] =~ "GAP #855"

      # 静态文本问询不能被 GAP 覆盖（正确落位，非缺口）
      assert em(world, "周芷若", "emei:qinggong").meta.inquiries["倚天剑"] ==
               "倚天不出，谁与争锋？唉！"

      assert em(world, "静慧师太", "emei:qfadadian").meta.inquiries["还俗"] ==
               "峨嵋弟子，不能还俗。你找掌门师太吧。"
    end

    test "门控联验：「灭剑」按 LPC 顺序贡献 → 等级链 → shen（lpc_emei）", %{world: world} do
      npc = em(world, "灭绝师太", "emei:hcahoudian")
      cfg = inquiry(npc, "灭剑")

      base =
        disciple(%{
          family: "峨嵋派",
          gongxian: 1000,
          shen: 30_000,
          max_neili: 0,
          skills: %{"force" => 180, "huifeng-jian" => 120}
        })

      assert {:ok, "huifeng-jian/mie", 1000} = SectMaster.inquiry_grant(base, npc_stats(npc), cfg)

      known = %{base | performs: MapSet.new(["huifeng-jian/mie"])}
      assert {:error, text} = SectMaster.inquiry_grant(known, npc_stats(npc), cfg)
      assert text =~ "这招我不是已经教过你了吗？"

      outsider = %{base | family: "武当派"}
      assert {:error, text} = SectMaster.inquiry_grant(outsider, npc_stats(npc), cfg)
      assert text =~ "你是哪里来的？快给我滚开！"

      no_skill = %{base | skills: %{}}
      assert {:error, text} = SectMaster.inquiry_grant(no_skill, npc_stats(npc), cfg)
      assert text =~ "你连回风拂柳剑法都没学"

      low_gx = %{base | gongxian: 999, shen: 0}
      assert {:error, text} = SectMaster.inquiry_grant(low_gx, npc_stats(npc), cfg)
      assert text =~ "哼，你在本派中无所作为"

      low_force = %{base | skills: %{"force" => 179, "huifeng-jian" => 120}, shen: 0}
      assert {:error, text} = SectMaster.inquiry_grant(low_force, npc_stats(npc), cfg)
      assert text =~ "你的内功修行太浅", "等级门必须先于侠义门命中"

      low_shen = %{base | shen: 29_999}
      assert {:error, text} = SectMaster.inquiry_grant(low_shen, npc_stats(npc), cfg)
      assert text =~ "你行侠仗义的事情还做得不够"
    end

    test "收徒门：峨眉女性 gender_first + bonze 师父拒俗家 + 灭绝/静慧额外门", %{
      world: world
    } do
      hui = em(world, "静慧师太", "emei:qfadadian").meta.apprentice
      assert hui.min_shen == 1000
      assert hui.min_skills == %{"mahayana" => 50}
      assert hui.min_shen_deny == "你行侠仗义之事还做的不够。"

      student = %{
        meta: %{
          family: %{name: "峨嵋派", class: "bonze"},
          env: %{gender: "女性"},
          stats: %{shen: 1000, combat_exp: 0, skills: %{"mahayana" => 50}}
        }
      }

      assert :ok = SectMaster.recruit_gate?(nil, student, hui)

      male = put_in(student, [:meta, :env, :gender], "男性")
      assert {:error, reason} = SectMaster.recruit_gate?(nil, male, hui)
      assert reason =~ "我峨嵋派不收男弟子"

      lay = put_in(student, [:meta, :family, :class], "fighter")
      assert {:error, reason} = SectMaster.recruit_gate?(nil, lay, hui)
      assert reason =~ "贫尼不收俗家弟子"

      low_shen = put_in(student, [:meta, :stats, :shen], 999)
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_shen, hui)
      assert reason =~ "你行侠仗义之事还做的不够"

      low_skill = put_in(student, [:meta, :stats, :skills], %{"mahayana" => 49})
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_skill, hui)
      assert reason =~ "你大乘涅磐功的修为还不够"

      miejue = em(world, "灭绝师太", "emei:hcahoudian").meta.apprentice
      assert miejue.min_shen == 30_000
      assert miejue.min_exp == 300_000
      assert miejue.min_skills == %{"mahayana" => 100, "emei-xinfa" => 100}
      assert miejue.rename_prefix == "静"
      assert miejue.min_shen_deny == "你行侠仗义之事做的太少！实在是太少！"

      fengling = em(world, "风陵师太", "emei:jinding").meta.apprentice
      assert fengling.min_shen == 30_000
      assert fengling.min_exp == 500_000
      assert fengling.min_skills == %{"mahayana" => 150, "linji-zhuang" => 150}
      assert fengling.rename_prefix == "灭"

      # 非 bonze 师父（贝锦仪）无 class 门
      bei = em(world, "贝锦仪", "emei:duguangtai").meta.apprentice
      assert is_nil(bei.require_class)
    end
  end

  # ---------------------------------------------------------------------------
  # 恒山派（henshan / 衡山派）—— Task #858-#862 本批
  # LPC: kungfu/class/henshan/{henshan.h,liu.c,lu.c,mi.c,mo.c,xiang.c}
  # ---------------------------------------------------------------------------

  describe "恒山派 UCL 数据回填（Task #859）" do
    defp hn(world, name, room) do
      npc = npc(world, name, room)
      assert npc, "#{name} 应随世界加载（#{room}）"
      npc
    end

    test "5 名 henshan NPC 的 teach/no_teach/apprentice 与 LPC 一致", %{world: world} do
      # 元组：NPC / 房间 / teach_skills 项数 / no_teach 项数 / shen / exp / min_skills
      for {name, room, skills, no_teach_count, shen, exp, min_skills} <- [
            {"刘正风", "hengyang:furongfeng", 21, 2, 30_000, 200_000,
             %{"henshan-jian" => 120, "force" => 150}},
            {"鲁连荣", "hengyang:tianzhu", 15, 1, 5_000, 50_000,
             %{"henshan-jian" => 50, "force" => 100}},
            {"米为义", "hengyang:zhurongdian", 13, 0, 0, 0, %{}},
            {"莫大", "hengyang:zhurongfeng", 21, 0, 40_000, 300_000,
             %{"henshan-jian" => 120, "force" => 180}},
            {"向大年", "hengyang:zigai", 14, 0, 2_000, 20_000,
             %{"henshan-jian" => 30, "force" => 80}}
          ] do
        npc = hn(world, name, room)
        teach = npc.meta.teach
        gate = npc.meta.apprentice

        assert teach, "#{name} 应有 teach"
        assert teach.family == "衡山派"

        assert map_size(teach.teach_skills) == skills,
               "#{name} teach_skills 应为 #{skills}，实际 #{map_size(teach.teach_skills)}"

        assert length(teach.no_teach) == no_teach_count, "#{name} no_teach"
        assert gate, "#{name} 应有 apprentice"
        assert gate.family == "衡山派"
        assert gate.permit_recruit == true
        assert gate.betray_sect_deny == "你当年都已经离开了衡山派，何必又要回来？"
        assert gate.betray_times_deny == "我们衡山派乃名门正派，决不收判师之徒！"
        assert gate.other_family_deny == "你既然已经有了名师指点，不好好学习，来我们衡山派作甚？"
        assert gate.min_shen == shen
        assert gate.min_exp == exp
        assert gate.min_skills == min_skills
      end

      # 逐字 no_teach（刘正风两项、鲁连荣一项）
      liu = hn(world, "刘正风", "hengyang:furongfeng")
      assert "liuyun-zhang" in liu.meta.teach.no_teach
      assert "shilin-jian" in liu.meta.teach.no_teach

      assert liu.meta.teach.no_teach_deny["liuyun-zhang"] ==
               "这流云掌向来只由掌门人亲授，你还是找我师兄传授吧！"

      lu = hn(world, "鲁连荣", "hengyang:tianzhu")
      assert lu.meta.teach.no_teach == ["zhenyue-jue"]

      assert lu.meta.teach.no_teach_deny["zhenyue-jue"] ==
               "这门内功我也是刚练不久，生疏得紧。"

      # Task #860：有序收徒技能链（henshan-jian 先于 force）
      assert liu.meta.apprentice.recruit_skill_order == ["henshan-jian", "force"]
      assert liu.meta.apprentice.min_skills_deny["henshan-jian"] =~ "最为重视剑法"
      assert liu.meta.apprentice.min_skills_deny["force"] =~ "内功却是御剑之本"

      # 米为义的 master_id 门（LPC mi.c:78-82）
      mi = hn(world, "米为义", "hengyang:zhurongdian")
      assert mi.meta.apprentice.reject_master_name == "xiang danian"

      assert mi.meta.apprentice.reject_master_name_deny ==
               "你既已拜我向师兄为师，我也不便收你为徒。"

      assert mi.meta.apprentice.min_shen_deny == "你这人不做好事，我衡山派可容你不得。"
    end

    test "5 名 henshan NPC combat 块完整（防回填误删战斗属性）", %{world: world} do
      for {name, room, exp, neili, qi, jing} <- [
            {"刘正风", "hengyang:furongfeng", 1_800_000, 4000, 4500, 2000},
            {"鲁连荣", "hengyang:tianzhu", 800_000, 3000, 2800, 1800},
            {"米为义", "hengyang:zhurongdian", 200_000, 1400, 3000, 2000},
            {"莫大", "hengyang:zhurongfeng", 3_000_000, 5000, 5000, 3000},
            {"向大年", "hengyang:zigai", 600_000, 2000, 1800, 1200}
          ] do
        npc = hn(world, name, room)
        assert npc.meta.stats.combat_exp == exp, "#{name} combat_exp"
        assert npc.meta.vitals.max_neili == neili, "#{name} max_neili"
        assert npc.meta.vitals.max_qi == qi, "#{name} max_qi"
        assert npc.meta.vitals.max_jing == jing, "#{name} max_jing"
      end
    end

    test "10 条 sect_master_grant：perform_id / 门控字段 / masterd 逐字文案", %{world: world} do
      # 元组：NPC / 房间 / 键 / perform_id / 必修技能 / 技能等级 /
      #       force / dodge / neili / 贡献 / shen / improve
      for {name, room, key, perform, skill, lv, force, dodge, neili, gx, shen, improve} <- [
            {"刘正风", "hengyang:furongfeng", "乱剑覆花", "furong-jian/luan", "furong-jian", 100, 140,
             140, 1600, 300, 20_000,
             ["sword", "sword", "furong-jian", "furong-jian", "martial-cognize"]},
            {"刘正风", "hengyang:furongfeng", "一剑落九雁", "luoyan-jian/luo", "luoyan-jian", 150, 220,
             220, 2800, 1500, 50_000,
             ["sword", "sword", "luoyan-jian", "luoyan-jian", "martial-cognize"]},
            {"鲁连荣", "hengyang:tianzhu", "幻剑式", "henshan-jian/huan", "henshan-jian", 60, 80, nil,
             nil, 50, 2_000,
             ["sword", "sword", "henshan-jian", "henshan-jian", "martial-cognize"]},
            {"鲁连荣", "hengyang:tianzhu", "烟云锁身", "tianzhu-jian/suo", "tianzhu-jian", 120, 150, 150,
             nil, 300, 20_000,
             ["sword", "sword", "tianzhu-jian", "tianzhu-jian", "martial-cognize"]},
            {"米为义", "hengyang:zhurongdian", "青天揽日月", "henshan-quan/lan", "henshan-quan", 60, 80,
             nil, nil, 50, 2_000,
             ["cuff", "cuff", "henshan-quan", "henshan-quan", "martial-cognize"]},
            {"莫大", "hengyang:zhurongfeng", "紫盖回翔", "zigai-jian/hui", "zigai-jian", 120, 150, 120,
             nil, 200, 15_000, ["sword", "sword", "zigai-jian", "zigai-jian", "martial-cognize"]},
            {"莫大", "hengyang:zhurongfeng", "落英纷飞", "shilin-jian/luo", "shilin-jian", 120, 180,
             nil, nil, 500, 50_000,
             ["sword", "sword", "shilin-jian", "shilin-jian", "martial-cognize"]},
            {"莫大", "hengyang:zhurongfeng", "流云叠影", "liuyun-zhang/die", "liuyun-zhang", 100, nil,
             150, nil, 300, 50_000,
             ["strike", "strike", "liuyun-zhang", "liuyun-zhang", "martial-cognize"]},
            {"莫大", "hengyang:zhurongfeng", "排山倒海", "liuyun-zhang/pai", "liuyun-zhang", 140, 180,
             nil, nil, 600, 50_000,
             ["strike", "strike", "liuyun-zhang", "liuyun-zhang", "martial-cognize"]},
            {"向大年", "hengyang:zigai", "峰连碧罗", "biluo-zhang/lian", "biluo-zhang", 100, 120, nil,
             nil, 200, 5_000,
             ["strike", "strike", "biluo-zhang", "biluo-zhang", "martial-cognize"]}
          ] do
        cfg = inquiry(hn(world, name, room), key)

        assert cfg, "#{name} 应能回答「#{key}」"
        assert cfg["kind"] == "sect_master_grant"
        assert cfg["perform_id"] == perform
        assert cfg["skill"] == skill
        assert cfg["family"] == "衡山派"
        assert cfg["gate_order"] == "lpc_masterd", "#{key} 须走 masterd.c 顺序"
        assert cfg["min_gongxian"] == gx
        assert cfg["cost_gongxian"] == gx
        assert cfg["min_shen"] == shen
        assert cfg["min_levels"] == %{skill => lv}
        assert cfg["level_order"] == [skill]
        assert is_binary(cfg["level_deny"][skill])
        assert cfg["improve_skills"] == improve
        assert cfg["maxed"] == "这招你不是已经会了么，还缠着我做甚？"
        assert cfg["family_deny"] == "大侠与我衡山派素无渊源，不知此话从何说起。"
        assert cfg["shen_deny"] == "你目前所做的侠义正事不够，这招暂时还不能传你。"
        assert cfg["gongxian_deny"] == "你为衡山派作出的贡献不够，这招暂时还不能传你。"
        assert cfg["learned"] == "你学会了「#{key}」。"

        if force do
          assert cfg["min_force"] == force
          assert cfg["force_deny"] == "你目前的内功火候不足，下去练练再来吧。"
        else
          refute Map.has_key?(cfg, "min_force")
        end

        if dodge do
          assert cfg["min_dodge"] == dodge
          assert cfg["dodge_deny"] == "你目前的轻功火候不足，下去练练再来吧。"
        else
          refute Map.has_key?(cfg, "min_dodge")
        end

        if neili do
          assert cfg["min_max_neili"] == neili
          assert cfg["max_neili_deny"] == "你现在的内力修为不足，修炼高点再来吧。"
        else
          refute Map.has_key?(cfg, "min_max_neili")
        end
      end

      # LPC 明写 msg1 的 4 条；其余 6 条是 masterd.c 的随机四段（GAP #866）
      for {name, room, key} <- [
            {"刘正风", "hengyang:furongfeng", "乱剑覆花"},
            {"鲁连荣", "hengyang:tianzhu", "幻剑式"},
            {"莫大", "hengyang:zhurongfeng", "流云叠影"},
            {"莫大", "hengyang:zhurongfeng", "排山倒海"}
          ] do
        assert inquiry(hn(world, name, room), key)["msg_one"] =~ "$N",
               "#{key} 须保留 LPC msg1 演示文案"
      end

      assert inquiry(hn(world, "莫大", "hengyang:zhurongfeng"), "落英纷飞")["msg_one"] == nil

      assert inquiry(hn(world, "鲁连荣", "hengyang:tianzhu"), "幻剑式")["skill_deny"] ==
               "你连衡山剑法都未曾学过，何谈绝招可言？"

      assert inquiry(hn(world, "向大年", "hengyang:zigai"), "峰连碧罗")["skill_deny"] ==
               "你连碧罗掌法都未曾学过，何谈绝招可言？"
    end

    test "状态类问询保留 GAP 标记，无 unimplemented 占位", %{world: world} do
      mo = hn(world, "莫大", "hengyang:zhurongfeng")

      for key <- ["历练", "历炼", "锻炼"] do
        assert mo.meta.inquiries[key] =~ "GAP #864", "#{key} 须登记 QUEST_D 缺口"
      end

      assert mo.meta.inquiries["镇岳尚方"] =~ "GAP #863"

      for {name, room} <- [
            {"刘正风", "hengyang:furongfeng"},
            {"鲁连荣", "hengyang:tianzhu"},
            {"米为义", "hengyang:zhurongdian"},
            {"莫大", "hengyang:zhurongfeng"},
            {"向大年", "hengyang:zigai"}
          ] do
        npc = hn(world, name, room)

        if is_map(npc.meta.inquiries) do
          refute Enum.any?(npc.meta.inquiries, fn {_k, v} ->
                   is_binary(v) and String.contains?(v, "unimplemented")
                 end),
                 "#{name} 仍有未实现问询占位"
        end
      end
    end

    test "门控联验：「乱剑覆花」按 masterd 顺序 shen → gx → 技能 → 力 → 轻功 → 内力", %{
      world: world
    } do
      npc = hn(world, "刘正风", "hengyang:furongfeng")
      cfg = inquiry(npc, "乱剑覆花")

      base =
        disciple(%{
          family: "衡山派",
          gongxian: 300,
          shen: 20_000,
          max_neili: 1600,
          skills: %{"furong-jian" => 100, "force" => 140, "dodge" => 140}
        })

      assert {:ok, "furong-jian/luan", 300} = SectMaster.inquiry_grant(base, npc_stats(npc), cfg)

      known = %{base | performs: MapSet.new(["furong-jian/luan"])}
      assert {:error, text} = SectMaster.inquiry_grant(known, npc_stats(npc), cfg)
      assert text =~ "还缠着我做甚"

      outsider = %{base | family: "武当派"}
      assert {:error, text} = SectMaster.inquiry_grant(outsider, npc_stats(npc), cfg)
      assert text =~ "素无渊源"

      # shen 门早于贡献门（同时失败时先报侠义文案）
      low_shen = %{base | shen: 19_999, gongxian: 0}
      assert {:error, text} = SectMaster.inquiry_grant(low_shen, npc_stats(npc), cfg)
      assert text =~ "侠义正事不够"

      low_gx = %{base | gongxian: 299}
      assert {:error, text} = SectMaster.inquiry_grant(low_gx, npc_stats(npc), cfg)
      assert text =~ "贡献不够"

      no_skill = %{base | skills: %{}}
      assert {:error, text} = SectMaster.inquiry_grant(no_skill, npc_stats(npc), cfg)
      assert text =~ "你连芙蓉剑法都未曾学过"

      low_skill = %{base | skills: %{"furong-jian" => 99, "force" => 140, "dodge" => 140}}
      assert {:error, text} = SectMaster.inquiry_grant(low_skill, npc_stats(npc), cfg)
      assert text =~ "了解还不够"

      low_force = %{base | skills: %{"furong-jian" => 100, "force" => 139, "dodge" => 140}}
      assert {:error, text} = SectMaster.inquiry_grant(low_force, npc_stats(npc), cfg)
      assert text =~ "内功火候不足"

      low_dodge = %{base | skills: %{"furong-jian" => 100, "force" => 140, "dodge" => 139}}
      assert {:error, text} = SectMaster.inquiry_grant(low_dodge, npc_stats(npc), cfg)
      assert text =~ "轻功火候不足"

      low_neili = %{base | max_neili: 1599}
      assert {:error, text} = SectMaster.inquiry_grant(low_neili, npc_stats(npc), cfg)
      assert text =~ "内力修为不足"
    end

    test "收徒门：henshan-jian 先于 force（有序链），米为义拒向大年弟子", %{world: world} do
      liu = hn(world, "刘正风", "hengyang:furongfeng").meta.apprentice

      student = %{
        meta: %{
          family: %{name: "衡山派"},
          stats: %{
            shen: 30_000,
            combat_exp: 200_000,
            skills: %{"henshan-jian" => 120, "force" => 150}
          }
        }
      }

      assert :ok = SectMaster.recruit_gate?(nil, student, liu)

      # 两项技能同时不足：必须先报「重视剑法」，验证 recruit_skill_order 生效
      both_low = put_in(student, [:meta, :stats, :skills], %{"henshan-jian" => 119, "force" => 0})
      assert {:error, reason} = SectMaster.recruit_gate?(nil, both_low, liu)
      assert reason =~ "最为重视剑法"

      low_force =
        put_in(student, [:meta, :stats, :skills], %{"henshan-jian" => 120, "force" => 149})

      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_force, liu)
      assert reason =~ "内功却是御剑之本"

      low_exp = put_in(student, [:meta, :stats, :combat_exp], 199_999)
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_exp, liu)
      assert reason =~ "经验尚浅"

      low_shen = put_in(student, [:meta, :stats, :shen], 29_999)
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_shen, liu)
      assert reason =~ "名门正派"

      mi = hn(world, "米为义", "hengyang:zhurongdian").meta.apprentice

      xiang_student = %{
        meta: %{
          family: %{name: "衡山派", master_name: "xiang danian"},
          stats: %{shen: 100, combat_exp: 0, skills: %{}}
        }
      }

      assert {:error, reason} = SectMaster.recruit_gate?(nil, xiang_student, mi)
      assert reason =~ "拜我向师兄为师"
    end
  end

  describe "梅庄 UCL 数据回填（Task #870）" do
    defp mz(world, name, room) do
      npc = npc(world, name, "meizhuang:#{room}")
      assert npc, "#{name} 应随世界加载（meizhuang:#{room}）"
      npc
    end

    # 收徒门控的玩家宿主：镜像 sect_master.recruit_gate?/3 读取的
    # meta.family(name/master_name) + meta.stats(shen/combat_exp/skills)。
    defp student(opts) do
      family = %{}
      family = if opts[:family], do: Map.put(family, :name, opts[:family]), else: family

      family =
        if opts[:master_name],
          do: Map.put(family, :master_name, opts[:master_name]),
          else: family

      %{
        meta: %{
          family: family,
          stats: %{
            shen: opts[:shen] || 0,
            combat_exp: opts[:exp] || 0,
            skills: opts[:skills] || %{}
          }
        }
      }
    end

    test "5 名梅庄 NPC 的 teach/no_teach 与 LPC set_skill 一致", %{world: world} do
      # 元组：NPC / 房间 / teach_skills 项数 / no_teach 技能列表
      for {name, room, skills, no_teach} <- [
            {"丹青生", "huashi", 16, []},
            {"丁坚", "keting", 11, []},
            {"黑白子", "houting", 17, []},
            {"黄钟公", "xiaowu", 20, ["longzhua-gong"]},
            {"秃笔翁", "shushi", 13, []}
          ] do
        npc = mz(world, name, room)
        teach = npc.meta.teach

        assert teach, "#{name} 应有 teach"
        assert teach.family == "梅庄"

        assert map_size(teach.teach_skills) == skills,
               "#{name} teach_skills 应为 #{skills}，实际 #{map_size(teach.teach_skills)}"

        assert Enum.sort(teach.no_teach) == Enum.sort(no_teach), "#{name} no_teach"
      end

      # 黄钟公龙爪功逐字拒教（LPC huang.c:69）；不得同时出现在 teach_skills
      huang = mz(world, "黄钟公", "xiaowu")

      refute Map.has_key?(huang.meta.teach.teach_skills, "longzhua-gong"),
             "龙爪功只能出现在 no_teach，不得同时可教"

      assert huang.meta.teach.no_teach_deny["longzhua-gong"] ==
               "龙爪功乃昔日方证大师所授的少林绝学，老夫略之一二，并不授教。"
    end

    test "5 名梅庄 NPC combat 块完整（防回填误删战斗属性）", %{world: world} do
      for {name, room, exp, neili, qi, jing} <- [
            {"丹青生", "huashi", 1_000_000, 4000, 3500, 3000},
            {"丁坚", "keting", 500_000, 3500, 3000, 2700},
            {"黑白子", "houting", 2_500_000, 5500, 5000, 4500},
            {"黄钟公", "xiaowu", 2_500_000, 6000, 6000, 5000},
            {"秃笔翁", "shushi", 2_000_000, 5000, 4500, 4000}
          ] do
        npc = mz(world, name, room)
        assert npc.meta.stats.combat_exp == exp, "#{name} combat_exp"
        assert npc.meta.vitals.max_neili == neili, "#{name} max_neili"
        assert npc.meta.vitals.max_qi == qi, "#{name} max_qi"
        assert npc.meta.vitals.max_jing == jing, "#{name} max_jing"
      end
    end

    test "5 名梅庄 NPC 的 apprentice 门控字段与 meizhuang.h 一致", %{world: world} do
      for {name, room, exp, shen, max_shen, no_min_shen, min_skills, order, any_skills} <- [
            {"丹青生", "huashi", 50_000, 0, nil, true, %{}, [],
             %{"wuzheng-xinfa" => 80, "xuantian-wujigong" => 80}},
            {"丁坚", "keting", 0, -1000, 1000, false, %{}, [], %{}},
            {"黑白子", "houting", 200_000, 0, nil, true, %{"force" => 120}, ["force"], %{}},
            {"黄钟公", "xiaowu", 400_000, 0, nil, true,
             %{"force" => 180, "sword" => 100, "unarmed" => 100}, ["force", "sword", "unarmed"],
             %{}},
            {"秃笔翁", "shushi", 50_000, 0, nil, true, %{}, [],
             %{"wuzheng-xinfa" => 80, "xuantian-wujigong" => 80}}
          ] do
        gate = mz(world, name, room).meta.apprentice

        assert gate, "#{name} 应有 apprentice"
        assert gate.family == "梅庄"
        assert gate.permit_recruit == true
        assert gate.gate_order == "lpc_meizhuang", "#{name} 须走 meizhuang.h 顺序"
        assert gate.betray_sect_deny == "你当年既然已经离开本庄，现在何必又要回来？"
        assert gate.betray_times_deny == "我梅庄虽小，但是也不会接纳你这样的背信弃义之徒！"
        assert gate.other_family_deny == "你既然已经有了名师指点，还来我们梅庄干嘛？"
        assert gate.min_exp == exp, "#{name} min_exp"
        assert gate.min_shen == shen, "#{name} min_shen"
        assert gate.max_shen == max_shen, "#{name} max_shen"
        assert gate.no_min_shen == no_min_shen, "#{name} no_min_shen"
        assert gate.min_skills == min_skills, "#{name} min_skills"
        assert gate.recruit_skill_order == order, "#{name} recruit_skill_order"
        assert gate.any_min_skills == any_skills, "#{name} any_min_skills"

        # 他派门例外 + move_party 分流字段（全部 5 名一致）
        assert gate.allow_families == ["日月神教"], "#{name} allow_families"
        assert gate.allow_master_name == "东方不败", "#{name} allow_master_name"
        assert gate.defer_family == "日月神教", "#{name} defer_family"
        assert gate.defer_master_name == "东方不败", "#{name} defer_master_name"
        assert gate.defer_mark == "move_party/日月神教--梅庄", "#{name} defer_mark"
        assert is_binary(gate.defer_msg) and gate.defer_msg != "", "#{name} defer_msg"
      end

      # 丁坚双向侠义门逐字
      ding = mz(world, "丁坚", "keting").meta.apprentice
      assert ding.min_shen_deny == "我们孤山梅庄向来不问江湖事，更不会结交名声不好之人。"
      assert ding.max_shen_deny == "我们孤山梅庄向来不问江湖事，也不结交你这样的侠义之士。"

      # 丹青生/秃笔翁「本门内功 OR 门」逐字 + 经验门
      dq = mz(world, "丹青生", "huashi").meta.apprentice
      assert dq.min_exp_deny == "你的江湖经验太浅，还是先多锻炼锻炼再说吧。"
      assert dq.any_min_skills_deny == "你连本门的内功都没学好，我收你做甚？"

      # 黑白子/黄钟公 defer_continue + delete_mark_on_accept + accept_msg
      for {name, room} <- [{"黑白子", "houting"}, {"黄钟公", "xiaowu"}] do
        g = mz(world, name, room).meta.apprentice
        assert g.defer_continue == true, "#{name} defer_continue"
        assert g.delete_mark_on_accept == true, "#{name} delete_mark_on_accept"
        assert g.accept_msg =~ "成为我梅庄中人", "#{name} accept_msg"
      end

      refute mz(world, "丹青生", "huashi").meta.apprentice.defer_continue == true,
             "丹青生不继续考察（return）"
    end

    test "10 条 sect_master_grant：perform_id / 门控 / 有序技能链 / 逐字文案", %{world: world} do
      # 元组：NPC / 房间 / 键 / perform_id / skill / 贡献 / min_levels / level_order
      for {name, room, key, perform, skill, gx, levels, order} <- [
            {"丹青生", "huashi", "醉里乾坤", "pomopima-jian/zui", "pomopima-jian", 300,
             %{"pomopima-jian" => 120, "force" => 150}, ["pomopima-jian", "force"]},
            {"丁坚", "keting", "电光四射", "jidian-jian/dian", "jidian-jian", 50,
             %{"jidian-jian" => 100, "force" => 150}, ["jidian-jian", "force"]},
            {"黑白子", "houting", "冰坚地狱", "xuantian-zhi/bing", "xuantian-zhi", 1500,
             %{"xuantian-wujigong" => 180, "xuantian-zhi" => 180},
             ["xuantian-wujigong", "xuantian-zhi"]},
            {"黑白子", "houting", "射日诀", "fenglei-zifa/she", "fenglei-zifa", 300,
             %{"fenglei-zifa" => 100}, ["fenglei-zifa"]},
            {"黑白子", "houting", "风雷四击", "fenglei-panfa/fenglei", "fenglei-panfa", 1000,
             %{"force" => 200, "fenglei-panfa" => 150}, ["force", "fenglei-panfa"]},
            {"黄钟公", "xiaowu", "七弦无形音", "qixian-wuxingjian/yin", "qixian-wuxingjian", 500,
             %{"force" => 250, "qixian-wuxingjian" => 160, "tanqin-jifa" => 120},
             ["force", "qixian-wuxingjian", "tanqin-jifa"]},
            {"黄钟公", "xiaowu", "七弦连环诛", "qixian-wuxingjian/zhu", "qixian-wuxingjian", 2000,
             %{"force" => 300, "qixian-wuxingjian" => 180, "tanqin-jifa" => 150},
             ["force", "qixian-wuxingjian", "tanqin-jifa"]},
            {"黄钟公", "xiaowu", "七弦黄龙闪", "qixian-wuxingjian/shan", "qixian-wuxingjian", 500,
             %{"force" => 250, "qixian-wuxingjian" => 160, "tanqin-jifa" => 120},
             ["force", "qixian-wuxingjian", "tanqin-jifa"]},
            {"秃笔翁", "shushi", "神笔封穴", "shigu-bifa/feng", "shigu-bifa", 300,
             %{"calligraphy" => 100, "shigu-bifa" => 100, "force" => 150},
             ["calligraphy", "shigu-bifa", "force"]},
            {"秃笔翁", "shushi", "诗意纵横", "shigu-bifa/shiyi", "shigu-bifa", 300,
             %{"calligraphy" => 100, "shigu-bifa" => 100, "force" => 150},
             ["calligraphy", "shigu-bifa", "force"]}
          ] do
        cfg = inquiry(mz(world, name, room), key)

        assert cfg, "#{name} 应能回答「#{key}」"
        assert cfg["kind"] == "sect_master_grant"
        assert cfg["perform_id"] == perform
        assert cfg["skill"] == skill
        assert cfg["family"] == "梅庄"
        assert cfg["gate_order"] == "lpc_meizhuang", "#{key} 须走 meizhuang.h 顺序"
        assert cfg["min_gongxian"] == gx
        assert cfg["cost_gongxian"] == gx
        assert cfg["min_levels"] == levels, "#{key} min_levels"
        assert cfg["level_order"] == order, "#{key} level_order"
        assert cfg["maxed"] == "我已经教过你了，自己下去练，别老是跟我纠缠不休。"
        assert cfg["family_deny"] == "大侠和本教素无瓜葛，何出此言？"
        assert cfg["gongxian_deny"] == "你对本庄所作出的贡献不够，这一招我暂时还不能传你。"
        assert cfg["learned"] =~ "你学会了「#{key}」"
        # meizhuang 无 shen/neili/dex 门（与 masterd 的关键差异）
        refute Map.has_key?(cfg, "min_shen")
        refute Map.has_key?(cfg, "min_max_neili")
        refute Map.has_key?(cfg, "min_force")
        refute Map.has_key?(cfg, "min_dex")
      end

      # 逐字 skill_deny（各庄不同技能）
      for {name, room, key, deny} <- [
            {"丹青生", "huashi", "醉里乾坤", "你连泼墨披麻剑都没学，何谈此言？"},
            {"丁坚", "keting", "电光四射", "你连疾电剑法都没学，何谈此言？"},
            {"黑白子", "houting", "冰坚地狱", "你连玄天指都没学，何谈此言？"},
            {"黑白子", "houting", "射日诀", "你连风雷子法都没学，何谈此言？"},
            {"黑白子", "houting", "风雷四击", "你连风雷盘法都没学，何谈此言？"},
            {"黄钟公", "xiaowu", "七弦无形音", "你连七弦无形剑都没学，何谈此言？"},
            {"秃笔翁", "shushi", "神笔封穴", "你连石鼓打穴笔法都没学，何谈此言？"}
          ] do
        assert inquiry(mz(world, name, room), key)["skill_deny"] == deny
      end

      # improve_skills 抽查（七弦三招一致）
      for key <- ["七弦无形音", "七弦连环诛", "七弦黄龙闪"] do
        assert inquiry(mz(world, "黄钟公", "xiaowu"), key)["improve_skills"] ==
                 ["unarmed", "sword", "force", "qixian-wuxingjian", "martial-cognize"]
      end
    end

    test "4 条 meizhuang_riyue：日月神教访客直授技能配置", %{world: world} do
      # 元组：NPC / 房间 / 直授技能 / 解锁绝招
      for {name, room, skill, unlocks} <- [
            {"丹青生", "huashi", "pomopima-jian", ["pomopima-jian/zui"]},
            {"黑白子", "houting", "fenglei-panfa", ["fenglei-panfa/fenglei"]},
            {"黄钟公", "xiaowu", "qixian-wuxingjian",
             ["qixian-wuxingjian/yin", "qixian-wuxingjian/shan", "qixian-wuxingjian/zhu"]},
            {"秃笔翁", "shushi", "shigu-bifa", ["shigu-bifa/feng", "shigu-bifa/shiyi"]}
          ] do
        cfg = inquiry(mz(world, name, room), "日月神教")

        assert cfg, "#{name} 应能回答「日月神教」"
        assert cfg["kind"] == "meizhuang_riyue"
        assert cfg["skill"] == skill
        assert cfg["family"] == "日月神教"
        assert cfg["granted_level"] == 10
        assert cfg["learn_mark"] == "can_learn/meizhuang"
        assert cfg["unlock_performs"] == unlocks
        # 严格 > 语义（LPC balance / gongxian 双严格大于）
        assert cfg["min_gongxian"] == 10_000
        assert cfg["cost_gongxian"] == 10_000
        assert cfg["min_bank_coins"] == 10_000_000_000
        assert cfg["cost_bank_coins"] == 10_000_000_000
        assert cfg["family_deny"] == "本庄只接待神教人士！"
        assert cfg["maxed"] == "你不是已经会了吗？还来找我干什么！"
        assert cfg["learned"] =~ "你学会了"
        assert cfg["say_teach"] =~ "我就教你"
        assert cfg["say_close"] == "下去好好练习吧。"
      end

      # 丁坚没有 ask_riyue 分支（LPC ding.c 无此函数）
      refute Map.has_key?(mz(world, "丁坚", "keting").meta.inquiries, "日月神教")
    end

    test "riyue_grant/2 门控：非日月神教拒 / 已学拒 / 神教弟子过", %{world: world} do
      cfg = inquiry(mz(world, "丹青生", "huashi"), "日月神教")

      outsider = %{family: "武当派", marks: %{}}
      assert {:error, text} = SectMaster.riyue_grant(outsider, cfg)
      assert text =~ "本庄只接待神教人士"

      member = %{family: "日月神教", marks: %{}}
      assert {:ok, "pomopima-jian", 10} = SectMaster.riyue_grant(member, cfg)

      # 已置 can_learn/meizhuang 标记 → maxed
      learned = %{family: "日月神教", marks: %{"can_learn/meizhuang" => 1}}
      assert {:error, text} = SectMaster.riyue_grant(learned, cfg)
      assert text =~ "你不是已经会了吗"
    end

    test "inquiry_grant 联验：醉里乾坤按 meizhuang 顺序 技能存在 → 贡献 → 有序等级", %{
      world: world
    } do
      npc = mz(world, "丹青生", "huashi")
      cfg = inquiry(npc, "醉里乾坤")

      base =
        disciple(%{
          family: "梅庄",
          gongxian: 300,
          skills: %{"pomopima-jian" => 120, "force" => 150}
        })

      assert {:ok, "pomopima-jian/zui", 300} = SectMaster.inquiry_grant(base, npc_stats(npc), cfg)

      known = %{base | performs: MapSet.new(["pomopima-jian/zui"])}
      assert {:error, text} = SectMaster.inquiry_grant(known, npc_stats(npc), cfg)
      assert text =~ "别老是跟我纠缠不休"

      outsider = %{base | family: "武当派"}
      assert {:error, text} = SectMaster.inquiry_grant(outsider, npc_stats(npc), cfg)
      assert text =~ "素无瓜葛"

      # 技能存在门早于贡献门：都没学时先报「没学泼墨披麻剑」
      no_skill = %{base | gongxian: 0, skills: %{}}
      assert {:error, text} = SectMaster.inquiry_grant(no_skill, npc_stats(npc), cfg)
      assert text =~ "你连泼墨披麻剑都没学"

      # 贡献门早于等级门：技能学会但贡献不足 → 贡献文案
      low_gx = %{base | gongxian: 299}
      assert {:error, text} = SectMaster.inquiry_grant(low_gx, npc_stats(npc), cfg)
      assert text =~ "贡献不够"

      # 贡献够但等级不足 → 有序等级链先报 pomopima-jian
      low_skill = %{base | skills: %{"pomopima-jian" => 119, "force" => 150}}

      assert {:error, text} = SectMaster.inquiry_grant(low_skill, npc_stats(npc), cfg)
      assert text =~ "泼墨披麻剑还练得不到家"

      # pomopima 够但 force 不足 → 报 force
      low_force = %{base | skills: %{"pomopima-jian" => 120, "force" => 149}}

      assert {:error, text} = SectMaster.inquiry_grant(low_force, npc_stats(npc), cfg)
      assert text =~ "内功火候尚不精纯"
    end

    test "收徒门联验：丹青生 defer（不 continue），丁坚双向侠义门，黑白子 defer_continue", %{
      world: world
    } do
      # 丹青生：日月神教/东方不败弟子 → {:defer, msg, mark}（return，不收徒）
      danqing = mz(world, "丹青生", "huashi").meta.apprentice

      dongfang =
        student(%{
          family: "日月神教",
          master_name: "东方不败",
          exp: 999_999,
          skills: %{"wuzheng-xinfa" => 999, "xuantian-wujigong" => 999}
        })

      assert {:defer, msg, "move_party/日月神教--梅庄"} =
               SectMaster.recruit_gate?(nil, dongfang, danqing)

      assert msg =~ "东方教主的弟子"

      # 丹青生：普通无门玩家 → any_min_skills（OR 内功门）不足被拒
      poor = student(%{family: nil, master_name: nil, exp: 60_000, skills: %{"sword" => 100}})

      assert {:error, reason} = SectMaster.recruit_gate?(nil, poor, danqing)
      assert reason =~ "本门的内功都没学好"

      # 丹青生：经验不足先报经验门
      low_exp = student(%{family: nil, master_name: nil, exp: 49_999, skills: %{}})
      assert {:error, reason} = SectMaster.recruit_gate?(nil, low_exp, danqing)
      assert reason =~ "经验太浅"

      # 丁坚：双向侠义门 —— 杀气过高被 max_shen 拒
      ding = mz(world, "丁坚", "keting").meta.apprentice

      too_righteous = student(%{family: nil, master_name: nil, exp: 0, shen: 1001, skills: %{}})

      assert {:error, reason} = SectMaster.recruit_gate?(nil, too_righteous, ding)
      assert reason =~ "不结交你这样的侠义之士"

      # 丁坚：杀气过低被 min_shen 拒
      too_evil = student(%{family: nil, master_name: nil, exp: 0, shen: -1001, skills: %{}})

      assert {:error, reason} = SectMaster.recruit_gate?(nil, too_evil, ding)
      assert reason =~ "不会结交名声不好之人"

      # 丁坚：杀气区间内通过
      ok_ding = student(%{family: nil, master_name: nil, exp: 0, shen: 0, skills: %{}})
      assert :ok = SectMaster.recruit_gate?(nil, ok_ding, ding)

      # 黑白子：defer_continue → 东方不败弟子拿到 ok_with_mark（通过后续门）
      heibai = mz(world, "黑白子", "houting").meta.apprentice

      dongfang2 =
        student(%{
          family: "日月神教",
          master_name: "东方不败",
          exp: 200_000,
          skills: %{"force" => 120}
        })

      assert {:ok_with_mark, _warn, "move_party/日月神教--梅庄"} =
               SectMaster.recruit_gate?(nil, dongfang2, heibai)

      # 黑白子：defer_continue 但内功不足 → error_with_mark（标记仍落盘）
      dongfang_low =
        student(%{
          family: "日月神教",
          master_name: "东方不败",
          exp: 200_000,
          skills: %{"force" => 119}
        })

      assert {:error_with_mark, reason, "move_party/日月神教--梅庄"} =
               SectMaster.recruit_gate?(nil, dongfang_low, heibai)

      assert reason =~ "内功火候太差"
    end

    test "GAP 标记：物品类问询保留 GAP 编号，无 unimplemented 占位", %{world: world} do
      assert mz(world, "黑白子", "houting").meta.inquiries["玄铁棋盘"] =~ "GAP #875"

      huang = mz(world, "黄钟公", "xiaowu")
      assert huang.meta.inquiries["白玉瑶琴"] =~ "GAP #876"
      assert huang.meta.inquiries["绿玉洞箫"] =~ "GAP #876"

      # 5 名 NPC 均不得残留「裸 unimplemented」占位（未登记 GAP 编号的才是不合格）
      for {name, room} <- [
            {"丹青生", "huashi"},
            {"丁坚", "keting"},
            {"黑白子", "houting"},
            {"黄钟公", "xiaowu"},
            {"秃笔翁", "shushi"}
          ] do
        npc = mz(world, name, room)

        bad =
          Enum.filter(npc.meta.inquiries, fn {_k, v} ->
            is_binary(v) and String.contains?(v, "unimplemented") and
              not String.contains?(v, "GAP #")
          end)

        assert bad == [], "#{name} 有裸 unimplemented 占位（未登记 GAP）: #{inspect(bad)}"
      end
    end
  end

  describe "嵩山派 UCL 数据回填（Task #890）" do
    defp ss(world, name, room) do
      npc = npc(world, name, "songshan:#{room}")
      assert npc, "#{name} 应随世界加载（songshan:#{room}）"
      npc
    end

    @tag songshan: true
    test "4 名嵩山师父 teach/apprentice/inquiries 与 LPC set_skill 一致", %{world: world} do
      # NPC / 房间 / teach_skills 项数 / inquiries 条数
      for {name, room, skills, grants} <- [
            {"狄修", "dadian", 13, 3},
            {"费彬", "chaotian", 16, 3},
            {"乐厚", "luyanpubu", 15, 2},
            {"左冷禅", "fengchantai", 19, 9}
          ] do
        c = ss(world, name, room)

        assert c.meta.teach.family == "嵩山派", "#{name} teach.family"
        assert map_size(c.meta.teach.teach_skills) == skills,
               "#{name} teach_skills 应为 #{skills}，实际 #{map_size(c.meta.teach.teach_skills)}"

        assert c.meta.apprentice.family == "嵩山派", "#{name} apprentice.family"
        assert c.meta.apprentice.permit_recruit == true, "#{name} permit_recruit"
        assert map_size(c.meta.inquiries) == grants,
               "#{name} inquiries 应为 #{grants}，实际 #{map_size(c.meta.inquiries)}"

        assert c.meta.chat_chance_combat == 120, "#{name} chat_chance_combat"
        assert c.meta.chat_msg_combat != [], "#{name} chat_msg_combat"
      end
    end

    @tag songshan: true
    test "4 名嵩山师父 combat 块完整（防回填误删战斗属性）", %{world: world} do
      for {name, room, exp, neili, qi, jing} <- [
            {"狄修", "dadian", 90_000, 1000, 1000, 1800},
            {"费彬", "chaotian", 600_000, 2000, 2000, 1200},
            {"乐厚", "luyanpubu", 70_000, 2000, 2000, 1200},
            {"左冷禅", "fengchantai", 1_850_000, 4800, 4500, 2200}
          ] do
        c = ss(world, name, room)

        assert c.meta.stats.combat_exp == exp, "#{name} combat_exp"
        assert c.meta.vitals.max_neili == neili, "#{name} max_neili"
        assert c.meta.vitals.max_qi == qi, "#{name} max_qi"
        assert c.meta.vitals.max_jing == jing, "#{name} max_jing"
      end

      # apply 块：费彬 60/60/60/120、左冷禅 100/100/100/200；狄修/乐厚无 apply
      fei = ss(world, "费彬", "chaotian").meta.combat_config.apply
      assert {fei.attack, fei.damage, fei.unarmed_damage, fei.armor} == {60, 60, 60, 120}

      zuo = ss(world, "左冷禅", "fengchantai").meta.combat_config.apply
      assert {zuo.attack, zuo.damage, zuo.unarmed_damage, zuo.armor} == {100, 100, 100, 200}

      for {name, room} <- [{"狄修", "dadian"}, {"乐厚", "luyanpubu"}] do
        ap = ss(world, name, room).meta.combat_config.apply
        assert ap.attack == 0 and ap.damage == 0 and ap.armor == 0, "#{name} 不应有 apply"
      end
    end

    @tag songshan: true
    test "apprentice 门控字段与 songshan.h / 四份 LPC attempt_apprentice 一致", %{world: world} do
      shared_denies = %{
        betray_sect_deny: "你当年都已经离开了嵩山派，何必又要回来？",
        betray_times_deny: "我们嵩山派乃名门正派，决不收判师之徒！",
        other_family_deny: "你既然已经有了名师指点，不好好学习，来我们嵩山派作甚？"
      }

      for {name, room, min_shen, no_min_shen, max_shen, exp, order, skills, accept} <- [
            {"狄修", "dadian", 0, false, nil, 0, [], %{},
             "既然如此，那你以后就跟着我吧。"},
            {"费彬", "chaotian", 30_000, false, nil, 200_000,
             ["songshan-jian", "songshan-xinfa"],
             %{"songshan-jian" => 120, "songshan-xinfa" => 100},
             "孺子可教，孺子可教。今日我就收下你吧。你以后定要勤练武，多行善，扬我嵩山派雄风。"},
            {"乐厚", "luyanpubu", 3_000, false, nil, 22_000,
             ["songshan-jian", "force"],
             %{"songshan-jian" => 40, "force" => 80},
             "我收下你便是，日后将我嵩山发扬光大。"},
            {"左冷禅", "fengchantai", 0, true, -30_000, 360_000,
             ["songshan-jian", "songshan-xinfa"],
             %{"songshan-jian" => 160, "songshan-xinfa" => 160},
             "孺子可教，孺子可教。今日我就收下你吧。你以后定要勤练武，扬我嵩山派雄风。"}
          ] do
        g = ss(world, name, room).meta.apprentice

        assert g.min_shen == min_shen, "#{name} min_shen"
        assert g.no_min_shen == no_min_shen, "#{name} no_min_shen"
        assert g.max_shen == max_shen, "#{name} max_shen"
        assert g.min_exp == exp, "#{name} min_exp"
        assert g.recruit_skill_order == order, "#{name} recruit_skill_order"
        assert g.min_skills == skills, "#{name} min_skills"
        assert g.accept_msg == accept, "#{name} accept_msg"

        for {field, text} <- shared_denies do
          assert Map.get(g, field) == text, "#{name} #{field}"
        end
      end

      # 逐字门控文案
      assert ss(world, "狄修", "dadian").meta.apprentice.min_shen_deny ==
               "你这人不做好事，我嵩山派可容你不得。"

      assert ss(world, "费彬", "chaotian").meta.apprentice.min_shen_deny ==
               "我嵩山剑派乃是堂堂名门正派，对弟子要求严格。你在这侠义与德行方面是否还做得不够？"

      assert ss(world, "乐厚", "luyanpubu").meta.apprentice.min_shen_deny ==
               "你非侠义之辈，岂能入我嵩山剑派？"

      assert ss(world, "左冷禅", "fengchantai").meta.apprentice.max_shen_deny ==
               "我最看不惯你们这些侠义之士，你还是请回吧！"
    end

    @tag songshan: true
    test "左冷禅 5 门绝招 + 残阳宝剑 give_item 字段（verbatim masterd.c）", %{world: world} do
      zuo = ss(world, "左冷禅", "fengchantai")
      i = zuo.meta.inquiries

      for {key, perform, skill, gx, shen, improve} <- [
            {"踏雪无痕", "hanbing-zhang/hen", "hanbing-zhang", 550, -32_000,
             ["hanbing-zhang", "parry", "strike", "martial-cognize"]},
            {"极天寒掌", "hanbing-zhang/han", "hanbing-zhang", 750, -48_000,
             ["hanbing-zhang", "parry", "strike", "martial-cognize"]},
            {"神光再现", "poyang-jian/xian", "poyang-jian", 650, -54_000,
             ["poyang-jian", "parry", "sword", "martial-cognize"]},
            {"天外玉龙", "poyang-jian/long", "poyang-jian", 900, -72_000,
             ["poyang-jian", "parry", "sword", "martial-cognize"]},
            {"寒冰真气", "hanbing-zhenqi/freezing", "hanbing-zhenqi", 1500, -93_000,
             ["hanbing-zhenqi", "force", "martial-cognize"]}
          ] do
        cfg = i[key]
        assert is_map(cfg), "#{key} 应为 map"
        assert cfg["kind"] == "sect_master_grant", "#{key} kind"
        assert cfg["perform_id"] == perform, "#{key} perform_id"
        assert cfg["skill"] == skill, "#{key} skill"
        assert cfg["gate_order"] == "lpc_masterd", "#{key} gate_order"
        assert cfg["min_gongxian"] == gx and cfg["cost_gongxian"] == gx, "#{key} gongxian"
        assert cfg["max_shen"] == shen, "#{key} max_shen"
        assert cfg["improve_skills"] == improve, "#{key} improve_skills"
        assert cfg["family_deny"] == "大侠与我嵩山派素无渊源，不知此话从何说起。"
      end

      sword = i["残阳宝剑"]

      assert sword["kind"] == "give_item"
      assert sword["item"] == "clone_lib:canyang"
      assert sword["match"] == "canyang"
      assert sword["unique"] in [true, "true"]
      assert sword["family"] == "嵩山派"
      assert sword["master_id"] in [true, "true"]
      assert sword["max_shen"] == -20_000
      # give_item 的 min_skill_levels 键在 loader 中不做 `_`→`-` 归一（handler 双查兜底）
      assert sword["min_skill_levels"] == %{"songshan_jian" => 120}
      assert sword["family_deny"] == "与我嵩山派素无渊源，不知此话从何说起。"
      assert sword["master_deny"] == "只有我的弟子才配使用残阳宝剑，你还是走吧。"
      assert sword["max_shen_deny"] == "哼！像你这样的心慈手软之辈，就算拿着残阳宝剑也是无用。"
      assert sword["min_skill_deny"] == "你的嵩山剑法火候未到，就算拿着残阳宝剑也没用。"
      assert sword["already"] == "那柄残阳宝剑不就是你拿着在用么，怎么反倒找我来了？"
      assert sword["success"] == "既然这样，那这柄残阳宝剑你就暂时拿去吧。"

      # GAP 占位必须带登记编号
      for key <- ["历练", "历炼", "锻炼"] do
        assert i[key] =~ "GAP #892", "#{key} 应登记 GAP #892"
      end
    end

    @tag songshan: true
    test "门控联验：狄修千斤锤过门 / 非同门拒绝", %{world: world} do
      cfg = inquiry(ss(world, "狄修", "dadian"), "千斤锤")
      stats = %{family: "嵩山派"}

      player =
        disciple(%{
          skills: %{"songshan-quan" => 30, "force" => 30},
          gongxian: 60,
          shen: 2000,
          family: "嵩山派"
        })

      assert {:ok, "songshan-quan/chui", 60} = SectMaster.inquiry_grant(player, stats, cfg)

      outsider =
        disciple(%{
          skills: %{"songshan-quan" => 30, "force" => 30},
          gongxian: 60,
          shen: 2000,
          family: "少林派"
        })

      assert {:error, "大侠与我嵩山派素无渊源，不知此话从何说起。"} =
               SectMaster.inquiry_grant(outsider, stats, cfg)
    end

    @tag songshan: true
    test "门控联验：左冷禅负侠义门（踏雪无痕 shen <= -32000）", %{world: world} do
      cfg = inquiry(ss(world, "左冷禅", "fengchantai"), "踏雪无痕")
      stats = %{family: "嵩山派"}

      qualified =
        disciple(%{
          skills: %{"hanbing-zhang" => 100, "force" => 160},
          gongxian: 550,
          shen: -33_000,
          family: "嵩山派"
        })

      assert {:ok, "hanbing-zhang/hen", 550} =
               SectMaster.inquiry_grant(qualified, stats, cfg)

      softhearted = %{qualified | shen: -31_999}

      assert {:error, "哼！像你这样的心慈手软之辈，又能干成什么大事？"} =
               SectMaster.inquiry_grant(softhearted, stats, cfg)
    end
  end
end

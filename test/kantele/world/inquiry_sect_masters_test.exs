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
      assert jianpu_xia["min_combat_exp"] == 300000
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
      assert xia_alias["min_combat_exp"] == 300000
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
      assert juehu["min_shen"] == 100000
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
        skills: %{"wudang-jian" => 60, "force" => 80, "zhenshan-zhang" => 40,
                  "yitian-zhang" => 120, "xuanxu-dao" => 100, "raozhi-roujian" => 100,
                  "huzhua-shou" => 120},
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

      assert {:error, "不是我们武当派的人，何出此言？"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
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
      player = wudang_disciple(%{skills: %{"zhenshan-zhang" => 39, "force" => 80,
                                          "wudang-jian" => 60, "yitian-zhang" => 120,
                                          "xuanxu-dao" => 100, "raozhi-roujian" => 100,
                                          "huzhua-shou" => 120},
                                 gongxian: 50, shen: 6000, max_neili: 200})

      assert {:error, "你的震山掌修为太浅，修炼好了再来吧。"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)
    end

    test "内力不足（谁与争锋 800）→ max_neili_deny", %{world: world} do
      cfg = inquiry(npc(world, "张翠山", "wudang:jiejianyan"), "谁与争锋")
      player = wudang_disciple(%{gongxian: 200, shen: 12000, max_neili: 799})

      assert {:error, "你的内力修为太浅，修炼高了再来吧。"} =
               SectMaster.inquiry_grant(player, %{family: "武当派"}, cfg)

      assert {:ok, "yitian-zhang/zheng", 200} =
               SectMaster.inquiry_grant(%{player | max_neili: 800},
                                        %{family: "武当派"}, cfg)
    end

    test "绝户神抓：shen < 100000 → shen_deny；达标过门", %{world: world} do
      cfg = inquiry(npc(world, "俞莲舟", "wudang:houyuan"), "绝户神抓")

      yu_skills = %{"force" => 180, "huzhua-shou" => 120}
      too_good = wudang_disciple(%{skills: yu_skills, gongxian: 400, shen: 99_999, max_neili: 1000})
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
          gongxian: 80, shen: 2000, max_neili: 300
        })

      assert {:error, "你的内功的修为不够，练高了再来吧。"} =
               SectMaster.inquiry_grant(weak_force, %{family: "武当派"}, cfg)

      weak_sword =
        wudang_disciple(%{
          skills: %{"force" => 80, "wudang-jian" => 59, "zhenshan-zhang" => 40},
          gongxian: 80, shen: 2000, max_neili: 300
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
      assert {:error, "你这人是怎么做的？连杀人都不会了？"} =
               SectMaster.inquiry_grant(good, %{family: "血刀门"}, cfg)

      evil = disciple(Map.merge(base, %{shen: -60_000, family: "血刀门"}))
      assert {:ok, "xuedao-dafa/resurrect", 500} =
               SectMaster.inquiry_grant(evil, %{family: "血刀门"}, cfg)
    end

    test "金刚印：force 与大手印逐技能拒绝文案", %{world: world} do
      cfg = inquiry(npc(world, "血刀老祖", "xuedao:shandong3"), "金刚印")
      base = %{gongxian: 200, shen: -15_000, max_neili: 1000, family: "血刀门"}

      weak_force =
        disciple(Map.merge(base, %{skills: %{"dashou-yin" => 100, "force" => 139}}))

      assert {:error, "你的内功修为实在太差，修炼高了再来找老夫吧。"} =
               SectMaster.inquiry_grant(weak_force, %{family: "血刀门"}, cfg)

      weak_skill =
        disciple(Map.merge(base, %{skills: %{"dashou-yin" => 99, "force" => 140}}))

      assert {:error, "等你把大手印练熟了再来找老夫。"} =
               SectMaster.inquiry_grant(weak_skill, %{family: "血刀门"}, cfg)
    end
  end
end

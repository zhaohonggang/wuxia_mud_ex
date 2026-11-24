defmodule Kantele.World.ShaolinTeachingTest do
  @moduledoc """
  #1046 少林派（shaolin）教学门控定向测试。

  数据来源：LPC `kungfu/class/shaolin/{du-e.c,du-jie.c,du-nan.c,du-yuan.c,jue-yuan.c,
  kong-jian.c,wuming.c,xuan-ji.c,xuan-ci.c,dao-chen.c,dao-xiang2.c,qing-le.c,
  hui-he.c,xu-ming.c,xu-tong.c,da-mo.c}`。重点锁定：

    1. 渡厄/渡劫/渡难：`no_teach`（shaolin-jiuyang 逐字拒）＋ `combat.apply`
       （attack/defense/damage/unarmed_damage 200、armor 300）＋ 战斗闲聊（whip 六条）；
    2. 渡元禅师：`combat.apply`（attack/defense/dodge 150、damage/unarmed_damage 200）＋
       战斗闲聊（sword 三式）；
    3. 觉远 / 空见 / 无名：`apprentice.deny_all = true` ＋ 逐字 `deny_msg`
       （LPC attempt_apprentice 均纯拒徒）；
    4. 空见：`meta.guarder`（family + 两句拒绝台词）＋ `coagents`（无名老僧）；
    5. 无名：`combat.apply`（attack/defense 300、unarmed_damage 150、armor 300）；
    6. 玄寂：战斗闲聊（claw.zhua）；
    7. 达摩：`combat.apply`（attack/defense 300、damage/unarmed_damage 150）；
    8. 道尘：五件武器 give_item（qimeigun/jiedao/chanzhang/changjian/changbian）＋
       `inquiry_state.wuqi_count = 15`；
    9. 道象2：金创药 give_item ＋ `inquiry_state.jin_count = 20`；
    10. 清乐：手谕/七十二绝艺（allow-letter）＋ 达摩令（damo-ling）give_item；
    11. 慧合：买铁 静态文案；玄慈：`pfm` 键（学习绝技清单文案）；
    12. 新增 xu_ming / xu_tong（虚明/虚通 知客僧）可加载。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  # loader 给 NPC 分配的运行时 id 是短 uuid，不能按静态 id 找；按别名查。
  # 注意道相(dao_xiang)与道象2(dao_xiang2)共享别名 "daoxiang chanshi"，
  # 需用区块 id 别名（"shaolin_dao_xiang2"）精确定位道象2。
  defp npc(world, alias_key) do
    Enum.find(world.characters, fn c ->
      Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
    end)
  end

  defp apply_of(world, alias_key) do
    npc(world, alias_key).meta.combat_config.apply
  end

  # ---------- 1. 渡厄/渡劫/渡难 no_teach + apply + 闲聊 ----------

  describe "渡厄/渡劫/渡难 —— no_teach + apply + 战斗闲聊" do
    @no_teach_deny "还是安心学习少林基础功夫吧。"

    test "no_teach shaolin-jiuyang 逐字拒", %{world: world} do
      for id <- ["du e", "du jie", "du nan"] do
        deny = npc(world, id).meta.teach.no_teach_deny
        assert deny == %{"shaolin-jiuyang" => @no_teach_deny}, "#{id} no_teach_deny"
      end
    end

    test "combat.apply attack/defense/damage/unarmed 200 + armor 300", %{world: world} do
      for id <- ["du e", "du jie", "du nan"] do
        a = apply_of(world, id)
        assert a.attack == 200, "#{id} attack"
        assert a.defense == 200, "#{id} defense"
        assert a.damage == 200, "#{id} damage"
        assert a.unarmed_damage == 200, "#{id} unarmed_damage"
        assert a.armor == 300, "#{id} armor"
      end
    end

    test "战斗闲聊 120 + whip 六条（顺序原样）", %{world: world} do
      for id <- ["du e", "du jie", "du nan"] do
        c = npc(world, id)
        assert c.meta.chat_chance_combat == 120, "#{id} chance"

        assert c.meta.chat_msg_combat ==
                 ["recover", "powerup", "shield", "whip.chan", "whip.he", "whip.shang"],
               "#{id} chat_msg_combat"
      end
    end
  end

  # ---------- 2. 渡元禅师 apply + 闲聊 ----------

  describe "渡元禅师 —— apply + 战斗闲聊" do
    test "apply attack/defense/dodge 150 + damage/unarmed 200", %{world: world} do
      a = apply_of(world, "duyuan chanshi")
      assert a.attack == 150
      assert a.defense == 150
      assert a.dodge == 150
      assert a.damage == 200
      assert a.unarmed_damage == 200
    end

    test "战斗闲聊 120 + sword 三式", %{world: world} do
      c = npc(world, "duyuan chanshi")
      assert c.meta.chat_chance_combat == 120

      assert c.meta.chat_msg_combat == [
               "recover",
               "powerup",
               "sword.gui",
               "sword.duo",
               "sword.pi"
             ]
    end
  end

  # ---------- 3. 觉远 / 空见 / 无名 纯拒徒 ----------

  describe "apprentice 门控 —— 觉远/空见/无名纯拒徒" do
    test "觉远 deny_all + 逐字 deny_msg", %{world: world} do
      app = npc(world, "jue yuan").meta.apprentice
      assert app.deny_all == true
      assert app.deny_msg == "贫僧乃戴罪之身，岂能收徒。"
    end

    test "空见 deny_all + 逐字 deny_msg（message_vision 转玩家视角）", %{world: world} do
      app = npc(world, "kong jian").meta.apprentice
      assert app.deny_all == true
      assert app.deny_msg == "空见双手合十对你道：善哉善哉，老衲早已不收徒了。"
    end

    test "无名 deny_all + 异门逐字 deny_msg", %{world: world} do
      app = npc(world, "wuming laoseng").meta.apprentice
      assert app.deny_all == true
      assert app.deny_msg == "我只是少林的一名扫地僧，哪里懂什么武功。"
    end
  end

  # ---------- 4. 空见守卫 + coagents ----------

  describe "空见 —— guarder + coagents + 战斗闲聊" do
    test "guarder family 少林派 + 两句拒绝台词", %{world: world} do
      g = npc(world, "kong jian").meta.guarder
      assert g.family == "少林派"
      assert g.msgs.refuse_other == "{npc}对{name}道：善哉，后殿只有少林弟子才能入内，施主还是请回吧！"
      assert g.msgs.refuse_carry == "{npc}对{name}道：你背上背的是谁？还不快快放下来？"
    end

    test "coagents 无名老僧（cjlou）", %{world: world} do
      coag = npc(world, "kong jian").meta.coagents
      assert coag == [%{"id" => "wuming laoseng", "startroom" => "shaolin:cjlou"}]
    end

    test "战斗闲聊 120 + strike/finger", %{world: world} do
      c = npc(world, "kong jian")
      assert c.meta.chat_chance_combat == 120
      assert c.meta.chat_msg_combat == ["strike.san", "finger.fuxue", "recover", "powerup"]
    end
  end

  # ---------- 5. 无名 / 达摩 apply ----------

  describe "无名/达摩 —— combat.apply" do
    test "无名 attack/defense 300 + unarmed_damage 150 + armor 300", %{world: world} do
      a = apply_of(world, "wuming laoseng")
      assert a.attack == 300
      assert a.defense == 300
      assert a.unarmed_damage == 150
      assert a.armor == 300
    end

    test "达摩 attack/defense 300 + damage/unarmed 150", %{world: world} do
      a = apply_of(world, "da mo")
      assert a.attack == 300
      assert a.defense == 300
      assert a.damage == 150
      assert a.unarmed_damage == 150
    end
  end

  # ---------- 6. 玄寂 战斗闲聊 ----------

  test "玄寂 战斗闲聊 claw.zhua", %{world: world} do
    c = npc(world, "xuanji dashi")
    assert c.meta.chat_chance_combat == 120
    assert c.meta.chat_msg_combat == ["recover", "powerup", "claw.zhua"]
  end

  # ---------- 7. 道尘 give_item ----------

  describe "道尘 —— 五件武器 give_item + wuqi_count" do
    @weapons %{
      "齐眉棍" => %{"item" => "shaolin:qimeigun", "match" => "qimeigun"},
      "戒刀" => %{"item" => "shaolin:jiedao", "match" => "jiedao"},
      "禅杖" => %{"item" => "shaolin:chanzhang", "match" => "chanzhang"},
      "长剑" => %{"item" => "shaolin:changjian", "match" => "changjian"},
      "皮鞭" => %{"item" => "shaolin:changbian", "match" => "changbian"}
    }

    test "五个 give_item 键，item/match 正确", %{world: world} do
      c = npc(world, "daochen chanshi")
      inq = c.meta.inquiries

      for {key, %{"item" => item, "match" => match}} <- @weapons do
        cfg = Map.get(inq, key)
        assert cfg, "缺 give_item 键 #{key}"
        assert cfg["kind"] == "give_item"
        assert cfg["item"] == item
        assert cfg["match"] == match
        assert cfg["family"] == "少林派"
        assert cfg["count"] == "wuqi_count"
        assert cfg["success"] == "拿去吧。不过要记住，武器只可防身练武，不可凭此杀害生灵。"
        assert cfg["family_deny"] == "与本派素无来往，不知此话从何谈起？"
        assert cfg["exhausted"] == "抱歉，你来得不是时候，武器已经发完了。"
      end
    end

    test "inquiry_state wuqi_count = 15", %{world: world} do
      c = npc(world, "daochen chanshi")
      assert c.meta.inquiry_state == %{"wuqi_count" => 15}
    end
  end

  # ---------- 8. 道象2 金创药 ----------

  describe "道象2 —— 金创药 give_item + jin_count" do
    test "金创药 give_item（须按区块 id 精确找，避开道相共享别名）", %{world: world} do
      c = npc(world, "shaolin_dao_xiang2")
      cfg = Map.get(c.meta.inquiries, "金创药")
      assert cfg
      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "shaolin:jinchuang_yao"
      assert cfg["match"] == "jinchuang_yao"
      assert cfg["count"] == "jin_count"
      assert cfg["family"] == "少林派"
      assert cfg["success"] == "好吧，记住，不到危急关头不要轻易使用此药。"
      assert cfg["already"] == "你现在身上不是有颗药丸吗，怎麼又来要了？ 真是贪得无餍！"
      assert cfg["exhausted"] == "对不起，金创药已经发完了"
    end

    test "inquiry_state jin_count = 20", %{world: world} do
      c = npc(world, "shaolin_dao_xiang2")
      assert c.meta.inquiry_state == %{"jin_count" => 20}
    end
  end

  # ---------- 9. 清乐 手谕/达摩令 ----------

  describe "清乐 —— 手谕/七十二绝艺/达摩令 give_item" do
    test "手谕/七十二绝艺 发 allow-letter，五技门槛", %{world: world} do
      c = npc(world, "qingle biqiu")

      for key <- ["手谕", "七十二绝艺"] do
        cfg = Map.get(c.meta.inquiries, key)
        assert cfg
        assert cfg["kind"] == "give_item"
        assert cfg["item"] == "shaolin:allow_letter"
        assert cfg["family"] == "少林派"
        assert cfg["min_skill_deny"] == "功力不够，不够资格领取手谕。"

        assert cfg["min_skill_levels"] == %{
                 "buddhism" => 150,
                 "dodge" => 100,
                 "shaolin_shenfa" => 100,
                 "force" => 100,
                 "parry" => 100
               }

        assert cfg["success"] == "好吧，凭这封手谕，你可自由进入藏经阁二楼研习上乘武功。"
      end
    end

    test "达摩令 发 damo-ling", %{world: world} do
      cfg = Map.get(npc(world, "qingle biqiu").meta.inquiries, "达摩令")
      assert cfg
      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "shaolin:damo_ling"
      assert cfg["family"] == "少林派"
      assert cfg["success"] == "好吧，凭这面达摩令，你可自由向你的师尊挑战。"
    end
  end

  # ---------- 10. 慧合 买铁 + 玄慈 pfm ----------

  describe "慧合/玄慈 —— 静态与 pfm 键" do
    test "慧合 买铁 静态文案", %{world: world} do
      cfg = Map.get(npc(world, "huihe zunzhe").meta.inquiries, "买铁")
      assert cfg == "买铁？ 他现在又不缺铁！ 前天老乔不是刚送来一堆铁块，铁手掌什麽的给他吗？！"
    end

    test "玄慈 pfm + 绝招 均返回学习绝技清单文案", %{world: world} do
      inq = npc(world, "xuanci dashi").meta.inquiries
      text = "你可以找我学习下列绝技: 一指点三脉,金刚伏魔诀,赤血连环爪。"
      assert Map.get(inq, "pfm") == text
      assert Map.get(inq, "绝招") == text
    end
  end

  # ---------- 11. xu_ming / xu_tong ----------

  describe "知客僧 xu_ming / xu_tong" do
    test "虚明（xu ming）可加载，gen 41 知客僧", %{world: world} do
      c = npc(world, "xu ming")
      assert c
      # 纯属性、无收徒/无询问
      refute c.meta.apprentice
      assert (c.meta.inquiries || %{}) == %{}
      assert c.meta.stats.combat_exp == 15000
    end

    test "虚通（xu tong）可加载，LPC 修正后的属性", %{world: world} do
      c = npc(world, "xu tong")
      assert c
      refute c.meta.apprentice
      assert (c.meta.inquiries || %{}) == %{}

      # 转换器曾误作 徐通(con35/exp15000)；LPC xu-tong.c 是 虚通(con20/exp2000/jiali100)。
      assert c.meta.stats.combat_exp == 2000
      assert c.meta.stats.con == 20
      assert c.meta.carry == ["shaolin:xu_cloth"]
    end

    test "山门只刷 1 个虚通（原重复 xu_tong 已修复）", %{world: world} do
      count =
        Enum.count(world.characters, fn c ->
          "xu tong" in (c.meta.aliases || [])
        end)

      assert count == 1
    end
  end
end

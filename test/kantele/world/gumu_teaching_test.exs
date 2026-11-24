defmodule Kantele.World.GumuTeachingTest do
  @moduledoc """
  #1006-#1008 古墓派教学门控定向测试。
  
  数据来源：LPC `kungfu/class/gumu/{gumu.h,li,lin,longnv,yang}.c` 与
  `adm/daemons/masterd.c`。重点锁定：
  
    1. 四份 `attempt_apprentice` 的逐字拒绝/接受文案与真实门序；
    2. 杨过 `gate_order = "lpc_gumu_yang"`：str → 玉女心经 → max_neili；
    3. 21 条 `teach_pfm` 的 `lpc_masterd` 门序 + 负神上界 + improve_skills；
    4. 小龙女银索金铃 give_item 与 4 NPC 战斗闲聊载荷。
  
  已知偏差（GAP #999-#1005，非本测试覆盖项）：ask_zhen/ask_xinjing/teach_sad
  状态机、QUEST_D 分发、masterd random(4) 文案、couple/guarder/coagent/temp 属性。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name) do
    Enum.find(world.characters, fn c -> c.name == name and c.meta.zone_id == "clone_lib" end)
  end

  defp li(world), do: npc(world, "李莫愁")
  defp lin(world), do: npc(world, "林朝英")
  defp longnv(world), do: npc(world, "小龙女")
  defp yang(world), do: npc(world, "杨过")

  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  # 收徒考察者：缺省满足古墓派各师父的硬门（负神/高经验/技能/内力）。
  defp recruit_student(overrides \\ %{}) do
    overrides = Map.new(overrides)

    stats =
      Map.merge(
        %{
          shen: -100_000,
          combat_exp: 500_000,
          str: 50,
          int: 40,
          per: 30,
          env_gender: nil,
          skills: %{"force" => 200, "strike" => 200, "yunv-xinjing" => 200}
        },
        Map.get(overrides, :stats, %{})
      )

    %{
      meta: %{
        family: Map.get(overrides, :family, %{name: "古墓派", master_name: nil}),
        env: Map.merge(%{gender: "女性"}, Map.get(overrides, :env, %{})),
        stats: stats,
        vitals: Map.get(overrides, :vitals, %{max_neili: 6000})
      }
    }
  end

  defp disciple(overrides \\ %{}) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, "古墓派")
    |> Map.put(:max_neili, 6000)
    |> Map.merge(Map.new(overrides))
  end

  # ---------- 1. 收徒门配置 ----------

  describe "apprentice 逐字文案与硬门配置" do
    test "李莫愁：性别/负神/经验/技能四门逐字文案落位", %{world: world} do
      app = li(world).meta.apprentice

      assert app.family == "古墓派"
      assert app.permit_recruit == true
      assert app.gender == "女性"
      assert app.gender_deny == "我李莫愁可不收臭男人做徒弟。"
      assert app.no_min_shen == true
      assert app.max_shen == -70000
      assert app.max_shen_deny == "我李莫愁可不收心慈手软的人做徒弟。"
      assert app.min_exp == 400_000
      assert app.min_skills == %{"force" => 160, "strike" => 120}
      assert app.recruit_skill_order == ["force", "strike"]
      assert app.accept_msg == "好吧，我就收下你这个徒弟了。"
    end

    test "林朝英：拒李莫愁弟子 + int35 + 玉女心经120，逐字文案", %{world: world} do
      app = lin(world).meta.apprentice

      assert app.reject_master_name == "李莫愁"
      assert app.reject_master_name_deny == "我林朝英可不收那叛徒的徒弟。"
      assert app.hard_min_int == 35
      assert app.int_deny == "我古墓派的功夫最讲一个悟字，你的资质不够。"
      assert app.no_min_shen == true
      assert app.min_skills == %{"yunv-xinjing" => 120}
      assert app.accept_msg == "好吧，看你也是性情中人，我就收下你这个徒弟了。"
    end

    test "小龙女：per26 门与逐字文案", %{world: world} do
      app = longnv(world).meta.apprentice

      assert app.no_min_shen == true
      assert app.min_per == 26
      assert app.per_deny == "尊容实在不敢恭维，我看你还是算了吧。"
      assert app.accept_msg == "好吧，我就收下你这个徒儿了。"
    end

    test "杨过：lpc_gumu_yang + str45 + 玉女心经120 + max_neili2000", %{world: world} do
      app = yang(world).meta.apprentice

      assert app.gate_order == "lpc_gumu_yang"
      assert app.permit_recruit == true
      assert app.no_min_shen == true
      assert app.min_str == 45
      assert app.str_deny == "连玄铁剑都拿不动，怎么做我徒弟。"
      assert app.min_skills == %{"yunv-xinjing" => 120}
      assert app.min_max_neili == 2000
      assert app.max_neili_deny == "你把内力锻炼好了再来也不迟啊！"
      assert app.accept_msg == "好吧，看你资质尚可，我就收下你这个徒弟了。"
    end
  end

  # ---------- 2. 收徒门运行 ----------

  describe "recruit_gate?/3 运行门序" do
    test "李莫愁：男性/心慈/经验浅/内功浅依次拒，合格收徒", %{world: world} do
      app = li(world).meta.apprentice
      good = recruit_student()

      # 缺省 permit_first 返回 :ok；逐字 accept_msg 由 FamilyEvent 渲染（已在上组断言）。
      assert :ok = SectMaster.recruit_gate?(nil, good, app)

      assert {:error, "我李莫愁可不收臭男人做徒弟。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(env: %{gender: "男性"}), app)

      # LPC `shen > -70000` 拒：-69999 命中 max_shen 门，-70000 放行。
      soft = recruit_student(stats: %{shen: -69_999})

      assert {:error, "我李莫愁可不收心慈手软的人做徒弟。\n"} = SectMaster.recruit_gate?(nil, soft, app)

      assert :ok = SectMaster.recruit_gate?(nil, recruit_student(stats: %{shen: -70_000}), app)

      assert {:error, "你这点能力怎能继承我的衣钵？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{combat_exp: 399_999}),
                 app
               )

      # force 先于 strike（recruit_skill_order）。
      assert {:error, "要学我五毒神掌，得先将内功练扎实。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{skills: %{"force" => 159, "strike" => 1}}),
                 app
               )

      assert {:error, "要学我的五毒神掌，需要精湛的掌法作基础，我看你在那上面下的工夫还不够啊。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{skills: %{"force" => 200, "strike" => 119}}),
                 app
               )
    end

    test "林朝英：叛徒门先于 int 与玉女心经门", %{world: world} do
      app = lin(world).meta.apprentice

      assert :ok = SectMaster.recruit_gate?(nil, recruit_student(), app)

      traitor = recruit_student(family: %{name: "古墓派", master_name: "李莫愁"})

      assert {:error, "我林朝英可不收那叛徒的徒弟。\n"} = SectMaster.recruit_gate?(nil, traitor, app)

      assert {:error, "我古墓派的功夫最讲一个悟字，你的资质不够。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(stats: %{int: 34}), app)

      assert {:error, "玉女心经乃本门绝学，你应该在这方面多加练习。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(stats: %{skills: %{"yunv-xinjing" => 119}}),
                 app
               )
    end

    test "小龙女：per25 拒、per26 收", %{world: world} do
      app = longnv(world).meta.apprentice

      assert :ok = SectMaster.recruit_gate?(nil, recruit_student(), app)

      assert {:error, "尊容实在不敢恭维，我看你还是算了吧。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(stats: %{per: 25}), app)
    end

    test "杨过：str → 玉女心经 → max_neili 三门顺序不可颠倒", %{world: world} do
      app = yang(world).meta.apprentice
      good = recruit_student()

      assert {:ok, "好吧，看你资质尚可，我就收下你这个徒弟了。\n"} = SectMaster.recruit_gate?(nil, good, app)

      # 三门同时不足时必须先报 str（缺省路径根本没有 str 门，且 max_neili 在技能前）。
      all_low =
        recruit_student(
          stats: %{str: 44, skills: %{"yunv-xinjing" => 1}},
          vitals: %{max_neili: 1000}
        )

      assert {:error, "连玄铁剑都拿不动，怎么做我徒弟。\n"} = SectMaster.recruit_gate?(nil, all_low, app)

      # str 达标后才是玉女心经；此时内力仍不足，但不得先报内力。
      skill_low =
        recruit_student(
          stats: %{skills: %{"yunv-xinjing" => 119}},
          vitals: %{max_neili: 1000}
        )

      assert {:error, "你还是先跟龙儿学点玉女心经吧。\n"} = SectMaster.recruit_gate?(nil, skill_low, app)

      # 前两门达标才轮到内力。
      neili_low = recruit_student(vitals: %{max_neili: 1999})

      assert {:error, "你把内力锻炼好了再来也不迟啊！\n"} = SectMaster.recruit_gate?(nil, neili_low, app)

      assert {:ok, _} =
               SectMaster.recruit_gate?(nil, recruit_student(vitals: %{max_neili: 2000}), app)
    end

    test "gumu.h permit 三问：离派/判师/他派逐字文案", %{world: world} do
      app = li(world).meta.apprentice

      leave = recruit_student(env: %{"detach" => %{"古墓派" => true}})

      assert {:error, "唉！去便去了，回来又是何苦由来？\n"} = SectMaster.recruit_gate?(nil, leave, app)

      betray = recruit_student(env: %{"betrayer" => %{"times" => 2}})

      assert {:error, "阁下不忠不信，我不敢收你为徒。\n"} = SectMaster.recruit_gate?(nil, betray, app)

      other = recruit_student(family: %{name: "全真派", master_name: nil})

      assert {:error, "你既有了名师指点，就要勤下苦功，勿要三心二意！\n"} = SectMaster.recruit_gate?(nil, other, app)
    end
  end

  # ---------- 3. 绝招 grant ----------

  describe "21 条 teach_pfm grant" do
    test "全部改走 lpc_masterd 且带 level_order / improve_skills", %{world: world} do
      grants =
        [li(world), lin(world), longnv(world), yang(world)]
        |> Enum.flat_map(fn ob ->
          ob.meta.inquiries
          |> Map.values()
          |> Enum.filter(&is_map/1)
          |> Enum.filter(&(&1["kind"] == "sect_master_grant"))
        end)

      assert length(grants) == 21
      assert Enum.all?(grants, &(&1["gate_order"] == "lpc_masterd"))
      assert Enum.all?(grants, &(is_list(&1["level_order"]) and &1["level_order"] != []))
      assert Enum.all?(grants, &(is_list(&1["improve_skills"]) and &1["improve_skills"] != []))

      # LPC masterd.c 每招 improve_skill(sk1) + valid_types + martial-cognize。
      assert inquiry(li(world), "寒冰针")["improve_skills"] == [
               "throwing",
               "bingpo-shenzhen",
               "martial-cognize"
             ]

      assert inquiry(yang(world), "卷字诀")["level_order"] == ["xuantie-jian", "force"]
      assert inquiry(longnv(world), "双剑合壁")["level_order"] == ["suxin-jian", "force", "dodge"]
    end

    test "李莫愁 8 条负神上界：min_shen → max_shen，masterd 门序先于贡献", %{world: world} do
      keys = ["风魔舞", "寒冰针", "无所不为", "赤心连环决", "千幻神诀", "无所不至", "无孔不入", "万毒噬心"]

      for key <- keys do
        cfg = inquiry(li(world), key)
        assert is_integer(cfg["max_shen"]) and cfg["max_shen"] < 0
        refute Map.has_key?(cfg, "min_shen")
        assert cfg["max_shen_deny"] == "哼！像你这样的心慈手软之辈，又能干成什么大事？"
      end

      cfg = inquiry(li(world), "风魔舞")
      npc_stats = %{family: "古墓派"}
      # shen=0 > -75000 且 gongxian=0 < 50：LPC masterd 先报杀气，不得报贡献。
      assert {:error, "哼！像你这样的心慈手软之辈，又能干成什么大事？"} =
               SectMaster.inquiry_grant(disciple(), npc_stats, cfg)

      evil = disciple(shen: -80_000, skills: %{"yunzhou-fufa" => 60}, gongxian: 50)

      assert {:ok, "yunzhou-fufa/feng", 50} = SectMaster.inquiry_grant(evil, npc_stats, cfg)
    end

    test "杨过 4 条 free:1：无同门门 + neili 映射 min_max_neili", %{world: world} do
      expected = %{"卷字诀" => 3000, "大江东去" => 5000, "黯然销魂" => 3200, "拖泥带水" => 4000}

      for {key, neili} <- expected do
        cfg = inquiry(yang(world), key)
        assert cfg["no_family_check"] == "true" or cfg["no_family_check"] == true
        assert cfg["min_max_neili"] == neili
      end

      cfg = inquiry(yang(world), "卷字诀")
      npc_stats = %{family: "古墓派"}

      # free:1 跳过同门门：外派玩家也可获授（LPC masterd.c:76）。
      outsider =
        disciple(
          family: "全真派",
          skills: %{"xuantie-jian" => 120, "force" => 450},
          max_neili: 3000
        )

      assert {:ok, "xuantie-jian/juan", 0} = SectMaster.inquiry_grant(outsider, npc_stats, cfg)

      low_neili =
        disciple(
          family: "全真派",
          skills: %{"xuantie-jian" => 120, "force" => 450},
          max_neili: 2999
        )

      assert {:error, "你的内力修为不够，学不成这招。\n"} = SectMaster.inquiry_grant(low_neili, npc_stats, cfg)
    end
  end

  # ---------- 4. 其它已落位数据 ----------

  describe "give_item 与战斗闲聊" do
    test "小龙女银索金铃：master_id + 银索金铃150 门 + 逐字文案", %{world: world} do
      cfg = inquiry(longnv(world), "银索金铃")

      assert cfg["kind"] == "give_item"
      assert cfg["item"] == "clone_lib:yinsuo"
      assert cfg["family"] == "古墓派"
      assert cfg["master_id"] == true or cfg["master_id"] == "true"
      assert cfg["min_skill_levels"] == %{"yinsuo_jinling" => 150}
      assert cfg["success"] == "既然这样，那这根银索金铃你就暂时拿去吧。"
    end

    test "4 NPC 战斗闲聊载荷逐字保留（LPC 闭包按命令语义落地）", %{world: world} do
      expected = %{
        li(world) => ["strike.huan", "strike.shi", "recover", "powerup"],
        lin(world) => [
          "sword.lian",
          "sword.feng",
          "sword.kai",
          "unarmed.you",
          "strike.wang",
          "recover",
          "powerup"
        ],
        longnv(world) => [
          "perform strike.wang and unarmed.you",
          "recover",
          "powerup",
          "whip.feng twice"
        ],
        yang(world) => ["strike.wang", "unarmed.xiao", "unarmed.tuo", "recover", "powerup"]
      }

      for {ob, payload} <- expected do
        assert ob.meta.chat_chance_combat == 120
        assert ob.meta.chat_msg_combat == payload
      end
    end
  end
end

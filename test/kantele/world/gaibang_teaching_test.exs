defmodule Kantele.World.GaibangTeachingTest do
  @moduledoc """
  #986 丐帮教学门控定向测试。
  数据来源：LPC `kungfu/class/gaibang/{gaibang.h,ada,bai,hong,jian,li,liang,lu,ma,peng,quan,wu,xi}.c`。

  重点锁定：
    1. 两个方向性 bug 修复：ada 无条件拒收（曾误收徒）、li 真实收徒（曾永不收徒）。
    2. `gate_order = "lpc_gaibang"` 的门序：permit(3) → exp → shen → beggarlvl →
       force(min_skills) → 属性门(str/四属性 OR) → max_neili。
    3. hong sk7 天下无狗的 requires_performs 四棒诀前置门。
    4. no_teach / coagents / shen_type / grant force=150 门。

  LPC→ex 已知偏差（已登记 GAP §5，非本测试覆盖项）：
    family/beggarlvl 落库、破布升袋/青竹令状态机、玉竹杖持有者、accept_object 食物链。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  # 名字 + clone_lib 区定位（阿大在 tulong 区有同名 NPC；clone_lib id 是哈希值）。
  defp npc(world, name) do
    Enum.find(world.characters, fn c -> c.name == name and c.meta.zone_id == "clone_lib" end)
  end

  defp ada(world), do: npc(world, "阿大")
  defp bai(world), do: npc(world, "白世镜")
  defp hong(world), do: npc(world, "洪七公")
  defp jian(world), do: npc(world, "简长老")
  defp li(world), do: npc(world, "黎生")
  defp liang(world), do: npc(world, "梁长老")
  defp lu(world), do: npc(world, "鲁有脚")
  defp ma(world), do: npc(world, "马大元")
  defp peng(world), do: npc(world, "彭有敬")
  defp quan(world), do: npc(world, "全冠清")
  defp wu(world), do: npc(world, "吴长风")
  defp inquiry(ob, key), do: ob.meta.inquiries[key]

  defp disciple(overrides \\ %{}) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, "丐帮")
    |> Map.put(:max_neili, 0)
    |> Map.merge(Map.new(overrides))
  end

  defp recruit_student(overrides \\ %{}) do
    overrides = Map.new(overrides)

    stats =
      Map.merge(
        %{
          shen: 100_000,
          combat_exp: 500_000,
          str: 35,
          int: 35,
          con: 35,
          dex: 35,
          skills: %{"force" => 200}
        },
        Map.get(overrides, :stats, %{})
      )

    %{
      meta: %{
        family: Map.get(overrides, :family, %{name: "丐帮", master_name: nil}),
        env:
          Map.put(Map.get(overrides, :env, %{}), :beggarlvl, Map.get(overrides, :beggarlvl, 9)),
        stats: stats,
        vitals: Map.get(overrides, :vitals, %{max_neili: 6000})
      }
    }
  end

  # ---------- 1. 两个关键 bug 修复 ----------

  describe "收徒方向性 bug 修复（ada 误收徒 / li 永不收徒）" do
    test "阿大 deny_all：无条件拒收，修复曾误收徒的漏洞", %{world: world} do
      ada = ada(world)
      assert ada, "阿大应随世界加载"
      assert ada.meta.apprentice.deny_all == true
      assert ada.meta.apprentice.deny_msg == "走开，我不收徒。"
    end

    test "黎生补 apprentice：permit + shen<0 拒，合格可收", %{world: world} do
      li = li(world)
      app = li.meta.apprentice
      assert app.gate_order == "lpc_gaibang"
      assert app.family == "丐帮"
      assert app.permit_recruit == true
      assert app.min_shen == 0
      assert app.accept_msg =~ "行侠仗义"

      # LPC li.c shen<0 拒
      evil = recruit_student(stats: %{shen: -1, combat_exp: 0, skills: %{}})
      assert {:error, "你为非作歹，竟然还想成为丐帮弟子？\n"} = SectMaster.recruit_gate?(nil, evil, app)

      # 合格（无 beggerlvl/exp 门，仅 shen≥0 + permit）
      ok =
        recruit_student(family: %{name: "丐帮"}, stats: %{shen: 5000, combat_exp: 0, skills: %{}})

      assert {:ok, "我便收你为徒，日后可得行侠仗义，莫损我丐帮名声。\n"} = SectMaster.recruit_gate?(nil, ok, app)
    end

    test "简长老/梁长老 deny_all：逐字拒收文案", %{world: world} do
      assert jian(world).meta.apprentice.deny_msg == "老夫不收徒弟，你还是请回吧。"
      assert liang(world).meta.apprentice.deny_msg == "老夫只负责给低袋弟子传功，并不收徒。"
    end
  end

  # ---------- 2. lpc_gaibang 收徒门序 ----------

  describe "recruit_gate?/3 lpc_gaibang 门序" do
    test "白世镜：permit → exp → shen → beggarlvl → force，逐门文案", %{world: world} do
      app = bai(world).meta.apprentice
      assert app.gate_order == "lpc_gaibang"
      assert app.min_exp == 120_000
      assert app.min_shen == 20_000
      assert app.min_beggarlvl == 4
      assert app.min_skills == %{"force" => 90}
      assert app.class == "beggar"

      base = %{
        stats: %{shen: 100_000, combat_exp: 500_000, skills: %{"force" => 200}},
        beggarlvl: 9
      }

      # exp 门
      assert {:error, "你的江湖经验不够，还是先向各位长老学习吧。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(
                   base
                   |> Map.put(:stats, %{
                     shen: 100_000,
                     combat_exp: 100_000,
                     skills: %{"force" => 200}
                   })
                 ),
                 app
               )

      # shen 门
      assert {:error, "你身为丐帮弟子，竟然不做好事？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(
                   base
                   |> Map.put(:stats, %{
                     shen: 1000,
                     combat_exp: 500_000,
                     skills: %{"force" => 200}
                   })
                 ),
                 app
               )

      # beggarlvl 门
      assert {:error, "你在本帮的地位太低，还是先向其他师父学习吧。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(base |> Map.put(:beggarlvl, 3)), app)

      # force 门
      assert {:error, "你的内功火候还不够，还是先向其他师父学习吧。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 recruit_student(
                   base
                   |> Map.put(:stats, %{
                     shen: 100_000,
                     combat_exp: 500_000,
                     skills: %{"force" => 50}
                   })
                 ),
                 app
               )

      # 通过
      assert {:ok, "我收下你便是，可别给我添麻烦。\n"} =
               SectMaster.recruit_gate?(nil, recruit_student(base), app)
    end

    test "洪七公：四属性 OR 门 + max_neili + 无 shen 门", %{world: world} do
      app = hong(world).meta.apprentice
      assert app.gate_order == "lpc_gaibang"
      assert app.min_any_attribute == 40
      assert app.no_min_shen == true
      assert app.min_max_neili == 2000

      # 四属性全 <40 → 拒
      weak =
        recruit_student(
          stats: %{
            shen: -5000,
            combat_exp: 500_000,
            skills: %{"force" => 200},
            str: 20,
            int: 20,
            con: 20,
            dex: 20
          }
        )

      assert {:error, "我说你这人体格也不行，脑筋也不灵光，还能和我学什么？\n"} = SectMaster.recruit_gate?(nil, weak, app)

      # 负神也可通过（无 shen 门），四属性其一 ≥40
      evil =
        recruit_student(
          stats: %{
            shen: -5000,
            combat_exp: 500_000,
            skills: %{"force" => 200},
            str: 50,
            int: 20,
            con: 20,
            dex: 20
          }
        )

      assert {:ok, _} = SectMaster.recruit_gate?(nil, evil, app)

      # max_neili 门
      low_neili =
        recruit_student(
          vitals: %{max_neili: 1000},
          stats: %{shen: 100_000, combat_exp: 500_000, skills: %{"force" => 200}, str: 50}
        )

      assert {:error, "就你那点内力哪里学得了什么上乘武功？\n"} = SectMaster.recruit_gate?(nil, low_neili, app)
    end

    test "马大元：query_str()<26 硬门（beggarlvl 5）", %{world: world} do
      app = ma(world).meta.apprentice
      assert app.min_str == 26
      assert app.min_beggarlvl == 5

      weak =
        recruit_student(
          beggarlvl: 6,
          stats: %{shen: 100_000, combat_exp: 500_000, skills: %{"force" => 200}, str: 20}
        )

      assert {:error, "我的武艺以刚猛为主，你膂力不行，还是算了吧。\n"} = SectMaster.recruit_gate?(nil, weak, app)
    end

    test "彭有敬/全冠清/吴长风/奚长老：门序与文案变体", %{world: world} do
      for npc <- [peng(world), quan(world)] do
        app = npc.meta.apprentice
        assert app.no_min_shen == true
      end

      # 吴长风/奚长老用「其他师父」变体，与 bai/lu 的「各位长老」变体区分。
      assert wu(world).meta.apprentice.min_exp_deny =~ "其他师父"
      assert npc(world, "奚长老").meta.apprentice.min_exp_deny =~ "其他师父"
      assert bai(world).meta.apprentice.min_exp_deny =~ "各位长老"
    end
  end

  # ---------- 3. 绝招门 ----------

  describe "绝招 grant 门" do
    test "洪七公天下无狗：requires_performs 四棒诀前置门", %{world: world} do
      cfg = inquiry(hong(world), "天下无狗")
      assert cfg["gate_order"] == "lpc_gaibang"

      assert cfg["requires_performs"] == [
               "dagou-bang/chan",
               "dagou-bang/chuo",
               "dagou-bang/feng",
               "dagou-bang/ban"
             ]

      npc_stats = %{family: "丐帮"}

      base_stats = %{
        shen: 100_000,
        gongxian: 3000,
        skills: %{"dagou-bang" => 250, "force" => 350},
        performs:
          MapSet.new(["dagou-bang/chan", "dagou-bang/chuo", "dagou-bang/feng", "dagou-bang/ban"]),
        beggarlvl: 9
      }

      # 四棒诀齐 → 通过
      assert {:ok, "dagou-bang/tian", 2000} =
               SectMaster.inquiry_grant(disciple(base_stats), npc_stats, cfg)

      # 缺一棒诀 → 拒
      missing = %{base_stats | performs: MapSet.new(["dagou-bang/chan"])}

      assert {:error, "你打狗棒法的四个棒诀都了解透彻了么？\n"} =
               SectMaster.inquiry_grant(disciple(missing), npc_stats, cfg)

      # LPC hong.c:653-654 family/beggarlvl<9 先于四棒诀门
      low_lvl = %{base_stats | beggarlvl: 8}

      assert {:error, "你在帮中的辈分还不够，等成为长老再说吧。\n"} =
               SectMaster.inquiry_grant(disciple(low_lvl), npc_stats, cfg)

      # LPC force 门槛先于打狗棒法等级，两门同时不足时按 level_order 报内功文案
      assert cfg["level_order"] == ["force", "dagou-bang"]
      low_force = %{base_stats | skills: %{"dagou-bang" => 100, "force" => 100}}

      assert {:error, "你的内功火候不足，回去练高点再来。"} =
               SectMaster.inquiry_grant(disciple(low_force), npc_stats, cfg)
    end

    test "22 条 grant 逐字保留 LPC message_sort 文案与各招 improve_skill 调用", %{world: world} do
      expected = %{
        {ada(world), ["傲尘剑", "焚阳剑", "观日神诀"]} => 3,
        {bai(world), ["缠丝擒拿"]} => 1,
        {hong(world),
         [
           "仙游诀",
           "金针渡劫",
           "缠字诀",
           "戳字诀",
           "封字诀",
           "绊字诀",
           "天下无狗",
           "双龙取水",
           "震惊百里",
           "飞龙在天",
           "亢龙有悔"
         ]} => 11,
        {li(world), ["五丁开山", "绝命一踢"]} => 2,
        {ma(world), ["铁爪锁喉"]} => 1,
        {peng(world), ["群魔乱舞"]} => 1,
        {wu(world), ["乌龙探海", "闪刀诀"]} => 2,
        {npc(world, "奚长老"), ["风火轮"]} => 1
      }

      for {{ob, keys}, count} <- expected do
        assert length(keys) == count

        for key <- keys do
          cfg = inquiry(ob, key)

          assert is_binary(cfg["msg_one"]) and byte_size(cfg["msg_one"]) > 0,
                 "#{key} msg_one"

          assert is_list(cfg["improve_skills"]) and cfg["improve_skills"] != [],
                 "#{key} improve_skills"
        end
      end

      tian = inquiry(hong(world), "天下无狗")

      assert tian["msg_one"] =~ "$n凝视了$N"
      assert tian["msg_one"] =~ "层层叠叠将$N笼罩于劲风之中"

      assert tian["improve_skills"] == [
               "staff",
               "staff",
               "staff",
               "dagou-bang",
               "dagou-bang",
               "dagou-bang",
               "martial-cognize"
             ]
    end

    test "白世镜缠丝擒拿 / 彭有敬群魔乱舞：force<150 独立门", %{world: world} do
      for {npc, key, skill} <- [
            {bai(world), "缠丝擒拿", "chansi-shou"},
            {peng(world), "群魔乱舞", "fengmo-zhang"}
          ] do
        cfg = inquiry(npc, key)
        assert cfg["min_levels"]["force"] == 150, "#{key} 应有 force=150 门"
        assert cfg["level_deny"]["force"] =~ "内功修为不足"

        # 主技能够但 force 不足 → 拒（gongxian/shen 需先满足）
        stats = %{
          gongxian: 2000,
          shen: 100_000,
          skills: %{skill => 200, "force" => 100},
          performs: MapSet.new()
        }

        assert {:error, _} = SectMaster.inquiry_grant(disciple(stats), %{family: "丐帮"}, cfg)
      end
    end
  end

  # ---------- 4. UCL 结构数据 ----------

  describe "UCL 结构回填（no_teach / coagents / shen_type）" do
    test "no_teach：li(2)/lu(4)/ma(1)/peng(1) 逐字硬拒文案", %{world: world} do
      assert length(li(world).meta.teach.no_teach) == 2
      assert length(lu(world).meta.teach.no_teach) == 4
      assert li(world).meta.teach.no_teach_deny["shenlong-baiwei"] =~ "蒙帮主"
      assert ma(world).meta.teach.no_teach_deny["dagou-bang"] =~ "继位帮主"
      assert peng(world).meta.teach.no_teach_deny["mihun-dafa"] =~ "下三滥"
    end

    test "coagents：li(2)/lu(1)/peng(1)/quan(3)", %{world: world} do
      assert length(li(world).meta.coagents) == 2
      assert length(lu(world).meta.coagents) == 1
      assert length(peng(world).meta.coagents) == 1
      assert length(quan(world).meta.coagents) == 3
      assert hd(quan(world).meta.coagents)["startroom"] == "city:ma_zhengting"
    end

    test "shen_type=-1 已落 UCL 数据（is_good 建模 GAP #983，meta 暂不暴露）", %{world: world} do
      # shen_type 在 ex 的 NonPlayerMeta 无字段（系统性 GAP #983），
      # 但 UCL 数据已逐字落盘，待引擎建模后可直接消费。
      raw = File.read!("data/world/clone_lib.ucl")

      assert raw =~ ~r/characters "gaibang_ada".*?shen_type = -1/s
      assert raw =~ ~r/characters "gaibang_peng".*?shen_type = -1/s
      assert world, "world 应正常加载（UCL 改动不破坏解析）"
    end

    test "战斗闲聊：12 NPC 逐字保留 LPC chat_msg_combat 闭包载荷", %{world: world} do
      # ex 当前把载荷当台词广播，perform_action/exert_function 命令语义属 GAP #954，
      # 但数据必须逐字落盘，待通用战斗 AI 落地后直接消费。
      expected = %{
        "阿大" => ["sword.fen", "sword.guan", "recover", "powerup"],
        "白世镜" => ["hand.qin", "recover", "powerup"],
        "洪七公" => [
          "strike.qu",
          "strike.zhen",
          "strike.fei",
          "dodge.xian",
          "staff.chan",
          "staff.chuo",
          "staff.feng",
          "staff.ban",
          "staff.tian",
          "recover",
          "powerup"
        ],
        "简长老" => ["strike.kai", "unarmed.jue", "staff.lun", "recover", "powerup"],
        "黎生" => ["recover", "powerup"],
        "梁长老" => ["staff.chan", "staff.feng", "staff.ban", "recover", "powerup"],
        "鲁有脚" => [
          "staff.chan",
          "staff.chuo",
          "staff.feng",
          "staff.ban",
          "staff.tian",
          "recover",
          "powerup"
        ],
        "马大元" => ["claw.suo", "recover", "powerup"],
        "彭有敬" => ["staff.luan", "recover", "powerup"],
        "全冠清" => ["strike.kai", "unarmed.jue", "blade.shan", "recover", "powerup"],
        "吴长风" => ["strike.tan", "blade.shan", "recover", "powerup"],
        "奚长老" => ["staff.lun", "recover", "powerup"]
      }

      for {name, msgs} <- expected do
        ob = npc(world, name)
        assert ob, "#{name} 应随世界加载"
        assert ob.meta.chat_chance_combat == 120, "#{name} chat_chance_combat"
        assert ob.meta.chat_msg_combat == msgs, "#{name} chat_msg_combat"
      end
    end
  end
end

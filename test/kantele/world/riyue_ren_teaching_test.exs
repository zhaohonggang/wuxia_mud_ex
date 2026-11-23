defmodule Kantele.World.RiyueRenTeachingTest do
  @moduledoc """
  #日月 任我行（LPC `kungfu/class/riyue/ren.c`）回填 + 门控联验。

  覆盖三层：
    1. UCL 数据（Loader 归一）：5 门绝招 `gate_order = "lpc_ren"` + `force_deny`/
       `skill_level_deny` + `improve_skills` + `requires_performs` + `learned` + `msg_one`；
       `teach.no_teach`（吸星大法技能阈值 unlock + 五岳剑派 5 条硬拒）；
       `apprentice`（lpc_ren 收徒门：permit / max_shen / exp / int / any_min_skills）；
       `chat_msg_combat` / `carry` / `combat.apply`。
    2. 门控行为：`SectMaster.inquiry_grant/3` 走 lpc_ren 逐字序（贡献先于杀气、
       内力先于内功、内功/绝招两档等级文案分列、反璞归真前置绝招）；
       `SectMaster.teachable?/3` 吸星大法 force>180 解锁与五岳剑派拒教；
       `SectMaster.recruit_gate?/3` lpc_ren 收徒门。
    3. `SectMasterGrant.render_msg1/2` 的 `{npc}`/`{name}` 归一化占位。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.InquiryHandlers.SectMasterGrant
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp ren(world), do: Enum.find(world.characters, fn c -> c.name == "任我行" end)
  defp inquiry(npc, key), do: npc.meta.inquiries[key]

  # 镜像 npc_script_event.stats_with_family/1：inquiry_grant 的同门校验读 npc.family。
  defp npc_stats(npc), do: %{family: (npc.meta.teach || %{}).family}

  # inquiry_grant 入参：%Stats{} + :family / :max_neili（宿主补的非 %Stats{} 字段）。
  defp disciple(overrides \\ %{}) do
    %Stats{skills: %{}, gongxian: 0, shen: 0, performs: MapSet.new()}
    |> Map.put(:family, nil)
    |> Map.put(:max_neili, 0)
    |> Map.merge(overrides)
  end

  # recruit_gate? 的 student：meta.family(map) / meta.env / meta.stats。
  defp recruit_student(overrides \\ %{}) do
    stats =
      Map.merge(
        %{shen: -100_000, combat_exp: 600_000, int: 40, skills: %{}},
        Map.get(overrides, :stats, %{})
      )

    %{
      meta: %{
        family: Map.get(overrides, :family, %{name: "日月神教"}),
        env: Map.get(overrides, :env, %{}),
        stats: stats
      }
    }
  end

  # ---------- 1. UCL 数据回填 ----------

  describe "UCL 数据回填（Loader 归一后）" do
    test "任我行 5 门绝招：lpc_ren 门控字段与 LPC ask_skill1..5 一致", %{world: world} do
      npc = ren(world)
      assert npc, "任我行应随世界加载"
      assert npc.meta.teach.family == "日月神教"

      gui = inquiry(npc, "天地归元")
      assert gui["gate_order"] == "lpc_ren"
      assert gui["perform_id"] == "yuanshi-jian/gui"
      assert gui["skill"] == "yuanshi-jian"
      assert gui["min_gongxian"] == 500
      assert gui["max_shen"] == -120_000
      assert gui["min_levels"] == %{"force" => 200, "yuanshi-jian" => 140}
      assert gui["cost_gongxian"] == 500
      assert gui["improve_skills"] == ["sword", "yuanshi-jian", "martial-cognize"]
      assert gui["force_deny"] == "你的内功火候尚需提高，练好了再来找我吧。"
      assert gui["skill_level_deny"] == "你的原始剑法还练得不到家，自己下去练练再来吧！"
      assert gui["learned"] == "你学会了「天地归元」。"
      assert gui["msg_one"] =~ "{npc}"
      refute gui["msg_one"] =~ "$"

      # 大巧若拙 / 大智若愚 / 反璞归真 有内力门槛
      assert inquiry(npc, "大巧若拙")["min_max_neili"] == 1800
      assert inquiry(npc, "大智若愚")["min_max_neili"] == 2800

      # 反璞归真 requires_performs + 3×3 improve
      zhen = inquiry(npc, "反璞归真")
      assert zhen["min_max_neili"] == 3600
      assert zhen["requires_performs"] == ["guzhuo-zhang/zhuo", "guzhuo-zhang/yu"]
      assert zhen["requires_perform_deny"] == "你连前两招都未练成，怎么学这最后一招？"

      assert zhen["improve_skills"] == [
               "strike",
               "strike",
               "strike",
               "guzhuo-zhang",
               "guzhuo-zhang",
               "guzhuo-zhang",
               "martial-cognize"
             ]
    end

    test "任我行 teach.no_teach：吸星大法技能阈值 unlock + 五岳剑派 5 条硬拒", %{world: world} do
      teach = ren(world).meta.teach

      unlock = teach.no_teach_unlock["xixing-dafa"]
      assert unlock, "吸星大法应有 unlock 段"
      assert unlock.mark == "can_learn/xixing-dafa/ren"
      assert unlock.min_skills == %{"force" => 180}
      assert unlock.locked == "你此时功力太浅，强修此功会走火入魔。"

      for skill <- [
            "taishan-sword",
            "hengshan-jian",
            "hengshan-sword",
            "huashan-jian",
            "songshan-sword"
          ] do
        assert teach.no_teach_deny[skill] == "你给我好好专研本门武功，五岳剑派的剑法学它作甚？"
      end
    end

    test "任我行 apprentice / chat / carry / apply 完整", %{world: world} do
      npc = ren(world)
      app = npc.meta.apprentice

      assert app.family == "日月神教"
      assert app.gate_order == "lpc_ren"
      assert app.permit_recruit == true
      assert app.reject_master_name == "任我行"
      assert app.no_min_shen == true
      assert app.max_shen == -80_000
      assert app.min_exp == 500_000
      assert app.hard_min_int == 34
      assert app.any_min_skills == %{"tianhuan-shenjue" => 150, "riyue-xinfa" => 150}

      # chat（战斗动作池）+ carry（佩饰）
      assert npc.meta.chat_chance_combat == 120
      assert "perform sword.gui" in npc.meta.chat_msg_combat
      assert "exert suck" in npc.meta.chat_msg_combat
      assert length(npc.meta.chat_msg_combat) == 8

      # combat.apply（set_temp apply/damage 100 / unarmed_damage 100 / armor 200）
      # loader 把 combat.apply 归一到 meta.combat.temp（NPCConfig.apply 同源）。
      temp = npc.meta.combat.temp
      assert temp.damage == 100
      assert temp.unarmed_damage == 100
      assert temp.armor == 200
    end
  end

  # ---------- 2. inquiry_grant lpc_ren 门序 ----------

  describe "inquiry_grant/3 lpc_ren 逐字门序" do
    test "贡献在杀气之前：贡献不足 + 杀气过高 → gongxian_deny", %{world: world} do
      npc = ren(world)
      cfg = inquiry(npc, "天地归元")

      player =
        disciple(%{
          skills: %{"yuanshi-jian" => 140, "force" => 200},
          gongxian: 499,
          shen: -100_000,
          family: "日月神教"
        })

      assert {:error, "你在教内甚无作为，这招我暂时还不能传你。"} =
               SectMaster.inquiry_grant(player, npc_stats(npc), cfg)
    end

    test "内力在内功等级之前：内力不足 + 内功不足 → max_neili_deny", %{world: world} do
      npc = ren(world)
      cfg = inquiry(npc, "大巧若拙")

      player =
        disciple(%{
          skills: %{"guzhuo-zhang" => 150, "force" => 100},
          gongxian: 600,
          shen: -120_000,
          family: "日月神教",
          max_neili: 1799
        })

      assert {:error, "你的内力太差，怎么修炼上乘武功？"} = SectMaster.inquiry_grant(player, npc_stats(npc), cfg)
    end

    test "内功等级 → 绝招技能等级：两档文案分列", %{world: world} do
      npc = ren(world)
      cfg = inquiry(npc, "天地归元")

      # 内功不足（force 199 < 200）→ force_deny
      weak_force =
        disciple(%{
          skills: %{"yuanshi-jian" => 200, "force" => 199},
          gongxian: 500,
          shen: -120_000,
          family: "日月神教"
        })

      assert {:error, "你的内功火候尚需提高，练好了再来找我吧。"} =
               SectMaster.inquiry_grant(weak_force, npc_stats(npc), cfg)

      # 内功达标、绝招技能不足（yuanshi-jian 139 < 140）→ skill_level_deny
      weak_skill =
        disciple(%{
          skills: %{"yuanshi-jian" => 139, "force" => 200},
          gongxian: 500,
          shen: -120_000,
          family: "日月神教"
        })

      assert {:error, "你的原始剑法还练得不到家，自己下去练练再来吧！"} =
               SectMaster.inquiry_grant(weak_skill, npc_stats(npc), cfg)

      # 全达标 → ok（且贡献恰好 500、杀气恰好 -120000 边界均放行）
      ok =
        disciple(%{
          skills: %{"yuanshi-jian" => 140, "force" => 200},
          gongxian: 500,
          shen: -120_000,
          family: "日月神教"
        })

      assert {:ok, "yuanshi-jian/gui", 500} = SectMaster.inquiry_grant(ok, npc_stats(npc), cfg)
    end

    test "反璞归真 requires_performs：缺 zhuo/任一招 → requires_perform_deny", %{world: world} do
      npc = ren(world)
      cfg = inquiry(npc, "反璞归真")

      base =
        disciple(%{
          skills: %{"guzhuo-zhang" => 220, "force" => 300},
          gongxian: 2200,
          shen: -200_000,
          family: "日月神教",
          max_neili: 3600
        })

      assert {:error, "你连前两招都未练成，怎么学这最后一招？"} = SectMaster.inquiry_grant(base, npc_stats(npc), cfg)

      only_zhuo = %{base | performs: MapSet.new(["guzhuo-zhang/zhuo"])}

      assert {:error, "你连前两招都未练成，怎么学这最后一招？"} =
               SectMaster.inquiry_grant(only_zhuo, npc_stats(npc), cfg)

      both = %{base | performs: MapSet.new(["guzhuo-zhang/zhuo", "guzhuo-zhang/yu"])}

      assert {:ok, "guzhuo-zhang/zhen", 2200} =
               SectMaster.inquiry_grant(both, npc_stats(npc), cfg)
    end
  end

  # ---------- 3. teachable? 吸星大法 / 五岳剑派 ----------

  describe "teachable?/3 任我行 no_teach" do
    test "吸星大法：force > 180 解锁 / 不足硬拒 / 持 mark 放行", %{world: world} do
      npc = ren(world)

      strong = %{meta: %{family: %{name: "日月神教"}, stats: %{skills: %{"force" => 181}}}}

      assert {:unlock, nil, "can_learn/xixing-dafa/ren"} =
               SectMaster.teachable?(npc, strong, "xixing-dafa")

      # 恰好 180 不算 > 180 → locked
      exact = %{meta: %{family: %{name: "日月神教"}, stats: %{skills: %{"force" => 180}}}}
      assert {:error, "你此时功力太浅，强修此功会走火入魔。"} = SectMaster.teachable?(npc, exact, "xixing-dafa")

      marked = %{
        meta: %{
          family: %{name: "日月神教"},
          stats: %{skills: %{}},
          marks: %{"can_learn/xixing-dafa/ren" => 1}
        }
      }

      assert {:unlock, nil, nil} = SectMaster.teachable?(npc, marked, "xixing-dafa")
    end

    test "五岳剑派剑法硬拒（no_teach_deny 逐字）", %{world: world} do
      npc = ren(world)
      student = %{meta: %{family: %{name: "日月神教"}, stats: %{skills: %{"force" => 300}}}}

      for skill <- [
            "taishan-sword",
            "hengshan-jian",
            "hengshan-sword",
            "huashan-jian",
            "songshan-sword"
          ] do
        assert {:error, "你给我好好专研本门武功，五岳剑派的剑法学它作甚？\n"} = SectMaster.teachable?(npc, student, skill)
      end
    end
  end

  # ---------- 4. recruit_gate? lpc_ren 收徒门 ----------

  describe "recruit_gate?/3 lpc_ren 收徒门" do
    test "全达标 → :ok", %{world: world} do
      npc = ren(world)

      student =
        recruit_student(%{
          stats: %{
            shen: -100_000,
            combat_exp: 600_000,
            int: 40,
            skills: %{"tianhuan-shenjue" => 150, "riyue-xinfa" => 150}
          }
        })

      assert :ok = SectMaster.recruit_gate?(npc, student)
    end

    test "杀气 > -80000 → max_shen_deny", %{world: world} do
      npc = ren(world)
      student = recruit_student(%{stats: %{shen: -79_999}})
      assert {:error, "老夫平生最痛恨的就是你这样的假仁假义之徒。\n"} = SectMaster.recruit_gate?(npc, student)
    end

    test "exp < 500000 → min_exp_deny", %{world: world} do
      npc = ren(world)
      student = recruit_student(%{stats: %{shen: -100_000, combat_exp: 499_999}})
      assert {:error, "你现在江湖经验太浅，还是先跟随几位长老学习吧。\n"} = SectMaster.recruit_gate?(npc, student)
    end

    test "int < 34 → int_deny", %{world: world} do
      npc = ren(world)
      student = recruit_student(%{stats: %{shen: -100_000, combat_exp: 600_000, int: 33}})
      assert {:error, "你悟性那么差，怎么领会我的武功？\n"} = SectMaster.recruit_gate?(npc, student)
    end

    test "any_min_skills OR 门：两门皆 < 150 → 拒；任一 ≥ 150 → 过", %{world: world} do
      npc = ren(world)

      both_low =
        recruit_student(%{
          stats: %{
            shen: -100_000,
            combat_exp: 600_000,
            int: 40,
            skills: %{"tianhuan-shenjue" => 149, "riyue-xinfa" => 149}
          }
        })

      assert {:error, "你连本门最基本的内功都没修好，怎么学习上乘武学。\n"} = SectMaster.recruit_gate?(npc, both_low)

      one_high =
        recruit_student(%{
          stats: %{
            shen: -100_000,
            combat_exp: 600_000,
            int: 40,
            skills: %{"tianhuan-shenjue" => 149, "riyue-xinfa" => 150}
          }
        })

      assert :ok = SectMaster.recruit_gate?(npc, one_high)
    end

    test "reject_master_name：任一 other_family 先拦；同门但 master=任我行 → reject_master_name_deny", %{
      world: world
    } do
      npc = ren(world)

      other =
        recruit_student(%{
          family: %{name: "武当派"},
          stats: %{shen: -100_000, combat_exp: 600_000, int: 40}
        })

      assert {:error, "你既然已经有了师承，又来我日月神教来干嘛？\n"} = SectMaster.recruit_gate?(npc, other)

      same_with_master =
        recruit_student(%{
          family: %{name: "日月神教", master_name: "任我行"},
          stats: %{
            shen: -100_000,
            combat_exp: 600_000,
            int: 40,
            skills: %{"tianhuan-shenjue" => 150, "riyue-xinfa" => 150}
          }
        })

      assert {:error, "既然教主慧眼识青，收你为徒，你就应该好好珍惜。你这样不求上进，朝三暮四，岂不辜负了教主的一片苦心？\n"} =
               SectMaster.recruit_gate?(npc, same_with_master)
    end
  end

  # ---------- 5. render_msg1 占位符 ----------

  describe "render_msg1/2 归一化占位" do
    test "{npc}/{name} 替换为 NPC/提问者名" do
      assert SectMasterGrant.render_msg1(
               "{npc}点了点头，随即便将{name}招至身边。",
               %{npc_name: "任我行", asker_name: "令狐冲"}
             ) == "任我行点了点头，随即便将令狐冲招至身边。"
    end

    test "$n/$N 旧占位仍兼容（GAP #822）" do
      assert SectMasterGrant.render_msg1(
               "$N右掌一竖，袭击向$n。",
               %{npc_name: "任我行", asker_name: "令狐冲"}
             ) == "任我行右掌一竖，袭击向令狐冲。"
    end
  end
end

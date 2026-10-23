defmodule Kantele.SectMasterTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats

  # 形状镜像真宿主（不再臆造）：
  # - 门派 family 是 map（%{name: ..}，family_event.ex:17）；字符串会 BadMapError
  # - 角色 shen/combat_exp 存在 meta.stats（%Stats{}，records.ex:143/153）；
  #   技能等级在 meta.stats.skills（string 键）
  # - 收徒门槛 config 是 meta.apprentice（loader parse_apprentice/1 产出形状）

  defp teacher(overrides \\ %{}) do
    Map.merge(
      %{
        meta: %{
          family: %{name: "武当派"},
          family_name: "武当派",
          teach: %{
            family: "武当派",
            teach_skills: %{
              "sword" => %{max: 40, gongxian: 2},
              "force" => %{max: 30, gongxian: 2}
            },
            no_teach: []
          },
          apprentice: %{
            family: "武当派",
            min_shen: 20_000,
            min_exp: 300_000,
            min_skills: %{},
            no_recruit: []
          },
          stats: %{combat_exp: 300_000, shen: 20_000, skills: %{"sword" => 40, "force" => 30}}
        }
      },
      overrides
    )
  end

  defp outsider_student do
    %{
      meta: %{
        family: %{name: "武当派"},
        family_name: "武当派",
        stats: %{combat_exp: 100_000, shen: 100, skills: %{"sword" => 10}}
      }
    }
  end

  defp other_sect_student do
    %{
      meta: %{
        family: %{name: "峨眉派"},
        family_name: "峨眉派",
        stats: %{combat_exp: 100_000, shen: 100, skills: %{"sword" => 10}}
      }
    }
  end

  test "teachable?/3：同门派非嫡传被 prevent_learn? 链拦（skills_event.ex:43-45）" do
    assert Kantele.SectMaster.teachable?(teacher(), outsider_student(), "sword") ==
             {:error, "你已入别派，老夫不便传授。\n"}
  end

  test "teachable?/3：NPC 无 meta.family、仅 teach.family 时同门非嫡传仍拦（skills_event.ex:38-44 同源）" do
    npc_teacher = %{
      meta: %{
        teach: %{family: "武当派", teach_skills: %{}, no_teach: []},
        apprentice: %{min_shen: 20_000, min_exp: 300_000, min_skills: %{}, no_recruit: []},
        stats: %{combat_exp: 300_000, shen: 20_000, skills: %{"sword" => 40}}
      }
    }

    assert Kantele.SectMaster.teachable?(npc_teacher, outsider_student(), "sword") ==
             {:error, "你已入别派，老夫不便传授。\n"}
  end

  test "teachable?/3：student_family 直接传 family map（build_conn 侧不包 meta 壳）" do
    npc_teacher = %{
      meta: %{
        teach: %{family: "武当派", teach_skills: %{}, no_teach: []},
        stats: %{skills: %{"sword" => 40}}
      }
    }

    student_family_map = %{name: "武当派", master_id: nil, master_name: nil}

    assert Kantele.SectMaster.teachable?(
             npc_teacher,
             %{meta: %{family: student_family_map}},
             "taiji-quan"
           ) ==
             {:error, "你已入别派，老夫不便传授。\n"}
  end

  test "teachable?/3：异门派由更高层收徒门槛把（此处贫口只负责本门门槛）" do
    assert Kantele.SectMaster.teachable?(teacher(), other_sect_student(), "sword") == :ok
  end

  test "teachable?/3：师父已不高于学生则拒授（skills_event.ex:63-69）" do
    peer = %{
      meta: %{
        family: %{name: "峨眉派"},
        stats: %{combat_exp: 300_000, shen: 100, skills: %{"sword" => 40}}
      }
    }

    assert Kantele.SectMaster.teachable?(teacher(), peer, "sword") ==
             {:error, "这一门功夫你已不弱于老夫，没什么可教的了。\n"}
  end

  test "recruit_gate?/3：shen/exp 真门槛（meta.apprentice 配置）" do
    assert {:error, "你的杀气不足，师父未同意收你为徒。\n"} =
             Kantele.SectMaster.recruit_gate?(teacher(), outsider_student())

    assert :ok =
             Kantele.SectMaster.recruit_gate?(
               teacher(%{meta: %{apprentice: %{min_shen: 20_000, min_exp: 300_000}}}),
               teacher_student()
             )
  end

  test "recruit_gate?/3：min_skills 心法门槛拦截" do
    strict =
      teacher(%{
        meta: %{apprentice: %{min_shen: 0, min_exp: 0, min_skills: %{"force" => 60}}}
      })

    weak_student = %{
      meta: %{
        family: %{name: "武当派"},
        stats: %{combat_exp: 100_000, shen: 100, skills: %{"force" => 20}}
      }
    }

    assert {:error, "你根基尚浅，这几样本事还未练成，先回去打好基础再来吧。\n"} =
             Kantele.SectMaster.recruit_gate?(strict, weak_student)
  end

  test "detach_penalty?/2：同门派叛师惩罚（family map 入参）" do
    assert {:penalty, _msg} = Kantele.SectMaster.detach_penalty?(%{name: "武当派"}, %{name: "武当派"})

    assert {:noop} = Kantele.SectMaster.detach_penalty?(%{name: "武当派"}, %{name: "峨眉派"})
  end

  defp teacher_student do
    %{
      meta: %{
        family: %{name: "武当派"},
        stats: %{combat_exp: 300_000, shen: 20_000, skills: %{"sword" => 40}}
      }
    }
  end

  # ---- inquiry_grant/3（镜像 class/wudang/yu.c ask_me；config 字符串键） ----

  defp yu_juehu_config do
    %{
      "perform_id" => "huzhua-shou/juehu",
      "skill" => "huzhua-shou",
      "min_levels" => %{"force" => 180, "huzhua-shou" => 120},
      "min_gongxian" => 400,
      "min_shen" => 100_000,
      "cost_gongxian" => 400
    }
  end

  defp qualify_stats(overrides \\ %{}) do
    Map.merge(
      %Stats{
        skills: %{"huzhua-shou" => 120, "force" => 180},
        gongxian: 400,
        shen: 100_000,
        performs: MapSet.new()
      },
      overrides
    )
  end

  test "inquiry_grant/3：全门槛达标返回 {:ok, perform_id, cost}（yu.c 成功分支）" do
    assert Kantele.SectMaster.inquiry_grant(qualify_stats(), %{}, yu_juehu_config()) ==
             {:ok, "huzhua-shou/juehu", 400}
  end

  test "inquiry_grant/3：已会则不重复授予（yu.c can_perform 分支）" do
    stats = qualify_stats(%{performs: MapSet.new(["huzhua-shou/juehu"])})

    assert {:error, "这一招你不是已经会了吗？\n"} =
             Kantele.SectMaster.inquiry_grant(stats, %{}, yu_juehu_config())
  end

  test "inquiry_grant/3：同门校验（两方都带 :family 才拦，yu.c 非同门分支）" do
    player = qualify_stats() |> Map.from_struct() |> Map.put(:family, "峨眉派")

    assert {:error, "你我并非同门，何来讨教绝招之说？\n"} =
             Kantele.SectMaster.inquiry_grant(player, %{family: "武当派"}, yu_juehu_config())

    # npc 未带 family → 无从判定，放行到后续门槛
    assert {:ok, "huzhua-shou/juehu", 400} =
             Kantele.SectMaster.inquiry_grant(player, %{}, yu_juehu_config())
  end

  test "inquiry_grant/3：未习核心技能（skill < 1，yu.c「连…都没学」）" do
    stats = qualify_stats(%{skills: %{"huzhua-shou" => 0, "force" => 180}})

    assert {:error, "你连huzhua-shou都没学，还谈什么绝招可言？\n"} =
             Kantele.SectMaster.inquiry_grant(stats, %{}, yu_juehu_config())
  end

  test "inquiry_grant/3：gongxian 门槛（yu.c 400）" do
    stats = qualify_stats(%{gongxian: 399})

    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(stats, %{}, yu_juehu_config())
  end

  test "inquiry_grant/3：shen 门槛（yu.c 100000）" do
    stats = qualify_stats(%{shen: 99_999})

    assert {:error, "这一招太过阴恨，若被你用去我恐怕不放心！\n"} =
             Kantele.SectMaster.inquiry_grant(stats, %{}, yu_juehu_config())
  end

  test "inquiry_grant/3：max_shen 上限（五毒 ask_skill1 shen > -20000 拒）" do
    config = %{
      "perform_id" => "xiewei-bian/tengshe",
      "skill" => "xiewei-bian",
      "min_levels" => %{"xiewei-bian" => 100},
      "min_gongxian" => 100,
      "max_shen" => -20_000,
      "cost_gongxian" => 100
    }

    allowed = %Stats{
      skills: %{"xiewei-bian" => 100},
      gongxian: 100,
      shen: -20_000,
      performs: MapSet.new()
    }

    # LPC `shen > -20000` 才拒；恰好 -20000 可通过
    assert Kantele.SectMaster.inquiry_grant(allowed, %{}, config) ==
             {:ok, "xiewei-bian/tengshe", 100}

    denied = %{allowed | shen: -19_999}

    assert {:error, "像你这样心慈手软，就算学了这招也干不了大事！\n"} =
             Kantele.SectMaster.inquiry_grant(denied, %{}, config)
  end

  test "inquiry_grant/3：min_levels 技能门槛（yu.c force 180 / huzhua-shou 120）" do
    low_force = qualify_stats(%{skills: %{"huzhua-shou" => 120, "force" => 179}})

    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(low_force, %{}, yu_juehu_config())

    low_claw = qualify_stats(%{skills: %{"huzhua-shou" => 119, "force" => 180}})

    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(low_claw, %{}, yu_juehu_config())
  end

  test "inquiry_grant/3：缺 perform_id 时拒（配置不完整）" do
    assert {:error, "这门绝招暂不外传。\n"} =
             Kantele.SectMaster.inquiry_grant(qualify_stats(), %{}, %{"skill" => "huzhua-shou"})
  end

  # ---- min_max_neili 内力门槛 + *_deny 文案覆盖（P5-4at） ----
  # 镜像 kungfu/class/{riyue/ren.c, honghua/wuchen.c, xuedao/*.c} 的
  # `query("max_neili") < N` 分支；max_neili 由调用方从 meta.vitals 并入 stats。

  defp neili_config(overrides \\ %{}) do
    Map.merge(
      %{
        "perform_id" => "guzhuo-zhang/zhuo",
        "skill" => "guzhuo-zhang",
        "min_levels" => %{"guzhuo-zhang" => 150, "force" => 220},
        "min_gongxian" => 600,
        "max_shen" => -120_000,
        "min_max_neili" => 1800,
        "cost_gongxian" => 600
      },
      overrides
    )
  end

  defp neili_player(overrides \\ %{}) do
    Map.merge(
      %Stats{
        skills: %{"guzhuo-zhang" => 150, "force" => 220},
        gongxian: 600,
        shen: -150_000,
        performs: MapSet.new()
      },
      overrides
    )
  end

  test "inquiry_grant/3：min_max_neili 达标（LPC max_neili >= 1800）" do
    player = neili_player(%{max_neili: 1800})

    assert {:ok, "guzhuo-zhang/zhuo", 600} =
             Kantele.SectMaster.inquiry_grant(player, %{}, neili_config())
  end

  test "inquiry_grant/3：min_max_neili 不足即拒（ren.c ask_skill3 内力分支）" do
    player = neili_player(%{max_neili: 1799})

    assert {:error, "你的内力修为不够，学不成这招。\n"} =
             Kantele.SectMaster.inquiry_grant(player, %{}, neili_config())
  end

  test "inquiry_grant/3：缺 min_max_neili 键不拦（老配置不受影响）" do
    player = neili_player(%{max_neili: 0})

    assert {:ok, "guzhuo-zhang/zhuo", 600} =
             Kantele.SectMaster.inquiry_grant(
               player,
               %{},
               Map.delete(neili_config(), "min_max_neili")
             )
  end

  test "inquiry_grant/3：max_neili 缺省按 0 计（调用方未并入 vitals 时从严）" do
    assert {:error, "你的内力修为不够，学不成这招。\n"} =
             Kantele.SectMaster.inquiry_grant(neili_player(), %{}, neili_config())
  end

  test "inquiry_grant/3：max_neili 经 %Stats{} 归一后仍在（Map.from_struct 不丢键）" do
    # 调用方 stats_with_family/1 把 vitals.max_neili 补进 %Stats{} 再传进来
    player = Map.put(neili_player(), :max_neili, 3600)

    assert {:ok, "guzhuo-zhang/zhuo", 600} =
             Kantele.SectMaster.inquiry_grant(player, %{}, neili_config())
  end

  test "inquiry_grant/3：*_deny 键逐条覆盖通用文案（门派问询每招文案不同）" do
    config =
      neili_config(%{
        "maxed" => "这一招我不是已经教过你了吗？",
        "family_deny" => "你又不是我日月神教的，跑来捣什么乱？",
        "skill_deny" => "你连古拙掌法都没学，还谈什么绝招可言？",
        "max_shen_deny" => "你这样心慈手软，就算学会这招又有什么用？",
        "gongxian_deny" => "你在教内甚无作为，这招我暂时还不能传你。",
        "level_deny" => "你的古拙掌法还练得不到家，自己下去练练再来吧！",
        "max_neili_deny" => "你的内力太差，怎么修炼上乘武功？"
      })

    assert {:error, "这一招我不是已经教过你了吗？"} =
             Kantele.SectMaster.inquiry_grant(
               neili_player(%{performs: MapSet.new(["guzhuo-zhang/zhuo"]), max_neili: 3600}),
               %{},
               config
             )

    assert {:error, "你又不是我日月神教的，跑来捣什么乱？"} =
             Kantele.SectMaster.inquiry_grant(
               neili_player(%{max_neili: 3600}) |> Map.from_struct() |> Map.put(:family, "峨眉派"),
               %{family: "日月神教"},
               config
             )

    assert {:error, "你连古拙掌法都没学，还谈什么绝招可言？"} =
             Kantele.SectMaster.inquiry_grant(
               neili_player(%{skills: %{"guzhuo-zhang" => 0, "force" => 220}, max_neili: 3600}),
               %{},
               config
             )

    assert {:error, "你这样心慈手软，就算学会这招又有什么用？"} =
             Kantele.SectMaster.inquiry_grant(
               neili_player(%{shen: -119_999, max_neili: 3600}),
               %{},
               config
             )

    assert {:error, "你在教内甚无作为，这招我暂时还不能传你。"} =
             Kantele.SectMaster.inquiry_grant(
               neili_player(%{gongxian: 599, max_neili: 3600}),
               %{},
               config
             )

    assert {:error, "你的古拙掌法还练得不到家，自己下去练练再来吧！"} =
             Kantele.SectMaster.inquiry_grant(
               neili_player(%{skills: %{"guzhuo-zhang" => 149, "force" => 220}, max_neili: 3600}),
               %{},
               config
             )

    assert {:error, "你的内力太差，怎么修炼上乘武功？"} =
             Kantele.SectMaster.inquiry_grant(neili_player(%{max_neili: 1799}), %{}, config)
  end

  test "inquiry_grant/3：未提供 *_deny 时仍走通用文案（回归）" do
    assert {:error, "你的内力修为不够，学不成这招。\n"} =
             Kantele.SectMaster.inquiry_grant(neili_player(%{max_neili: 0}), %{}, neili_config())
  end

  # ---- wudang_zhang ask_skill1..11 → perform_id 门槛测试（kungfu/class/wudang/zhang.c） ----
  # 每门绝招：family=武当派 + skill >= 1 + gongxian >= N + shen >= N + min_levels 达标 → {:ok, perform_id, cost}

  defp wudang_player(overrides \\ %{}) do
    Map.merge(
      %Stats{
        skills: %{
          "taiji-shengong" => 420,
          "taiji-quan" => 420,
          "taiji-jian" => 420,
          "taoism" => 400,
          "force" => 420
        },
        gongxian: 5000,
        shen: 200_000,
        performs: MapSet.new()
      },
      overrides
    )
  end

  # ask_skill1：鹤嘴劲 — taiji-shengong/dian (skill>=1, gongxian>=800, shen>=150000, taiji-shengong>=100)
  defp cfg_dian do
    %{
      "perform_id" => "taiji-shengong/dian",
      "skill" => "taiji-shengong",
      "min_levels" => %{"taiji-shengong" => 100},
      "min_gongxian" => 800,
      "min_shen" => 150_000,
      "cost_gongxian" => 800
    }
  end

  test "inquiry_grant/3：wudang 鹤嘴劲（taiji-shengong/dian）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_dian()) ==
             {:ok, "taiji-shengong/dian", 800}
  end

  test "inquiry_grant/3：wudang 鹤嘴劲 — 非同门拒绝" do
    assert {:error, "你我并非同门，何来讨教绝招之说？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_player() |> Map.from_struct() |> Map.put(:family, "峨眉派"),
               %{family: "武当派"},
               cfg_dian()
             )
  end

  test "inquiry_grant/3：wudang 鹤嘴劲 — 未习核心技能拒绝" do
    assert {:error, "你连taiji-shengong都没学，还谈什么绝招可言？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_player(%{
                 skills: %{
                   "taiji-shengong" => 0,
                   "taiji-quan" => 420,
                   "taiji-jian" => 420,
                   "taoism" => 400,
                   "force" => 420
                 }
               }),
               %{family: "武当派"},
               cfg_dian()
             )
  end

  test "inquiry_grant/3：wudang 鹤嘴劲 — gongxian 不足拒绝" do
    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_player(%{gongxian: 799}),
               %{family: "武当派"},
               cfg_dian()
             )
  end

  test "inquiry_grant/3：wudang 鹤嘴劲 — shen 不足拒绝" do
    assert {:error, "这一招太过阴恨，若被你用去我恐怕不放心！\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_player(%{shen: 149_999}),
               %{family: "武当派"},
               cfg_dian()
             )
  end

  test "inquiry_grant/3：wudang 鹤嘴劲 — min_levels 不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_player(%{
                 skills: %{
                   "taiji-shengong" => 99,
                   "taiji-quan" => 420,
                   "taiji-jian" => 420,
                   "taoism" => 400,
                   "force" => 420
                 }
               }),
               %{family: "武当派"},
               cfg_dian()
             )
  end

  # ask_skill2：震字诀 — taiji-quan/zhen (gongxian>=300, shen>=100000, taiji-quan>=150)
  defp cfg_zhen do
    %{
      "perform_id" => "taiji-quan/zhen",
      "skill" => "taiji-quan",
      "min_levels" => %{"taiji-quan" => 150},
      "min_gongxian" => 300,
      "min_shen" => 100_000,
      "cost_gongxian" => 300
    }
  end

  test "inquiry_grant/3：wudang 震字诀（taiji-quan/zhen）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_zhen()) ==
             {:ok, "taiji-quan/zhen", 300}
  end

  # ask_skill3：引字诀 — taiji-quan/yin (gongxian>=200, shen>=100000, taiji-quan>=150)
  defp cfg_yin do
    %{
      "perform_id" => "taiji-quan/yin",
      "skill" => "taiji-quan",
      "min_levels" => %{"taiji-quan" => 150},
      "min_gongxian" => 200,
      "min_shen" => 100_000,
      "cost_gongxian" => 200
    }
  end

  test "inquiry_grant/3：wudang 引字诀（taiji-quan/yin）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_yin()) ==
             {:ok, "taiji-quan/yin", 200}
  end

  # ask_skill4：挤字诀 — taiji-quan/ji (gongxian>=400, shen>=120000, taiji-quan>=150)
  defp cfg_ji do
    %{
      "perform_id" => "taiji-quan/ji",
      "skill" => "taiji-quan",
      "min_levels" => %{"taiji-quan" => 150},
      "min_gongxian" => 400,
      "min_shen" => 120_000,
      "cost_gongxian" => 400
    }
  end

  test "inquiry_grant/3：wudang 挤字诀（taiji-quan/ji）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_ji()) ==
             {:ok, "taiji-quan/ji", 400}
  end

  # ask_skill5：粘字诀 — taiji-quan/zhan (gongxian>=500, shen>=140000, taiji-quan>=150)
  defp cfg_zhan do
    %{
      "perform_id" => "taiji-quan/zhan",
      "skill" => "taiji-quan",
      "min_levels" => %{"taiji-quan" => 150},
      "min_gongxian" => 500,
      "min_shen" => 140_000,
      "cost_gongxian" => 500
    }
  end

  test "inquiry_grant/3：wudang 粘字诀（taiji-quan/zhan）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_zhan()) ==
             {:ok, "taiji-quan/zhan", 500}
  end

  # ask_skill6：太极图 — taiji-quan/tu (gongxian>=3000, shen>=250000, taiji-quan>=250, taiji-shengong>=300, taoism>=300)
  defp cfg_tu do
    %{
      "perform_id" => "taiji-quan/tu",
      "skill" => "taiji-quan",
      "min_levels" => %{"taiji-quan" => 250, "taiji-shengong" => 300, "taoism" => 300},
      "min_gongxian" => 3000,
      "min_shen" => 250_000,
      "cost_gongxian" => 3000
    }
  end

  test "inquiry_grant/3：wudang 太极图（taiji-quan/tu）全门槛达标 → {:ok}" do
    # 太极图的 shen 门槛是 250000，比 wudang_player/0 的默认 200000 高
    assert Kantele.SectMaster.inquiry_grant(
             wudang_player(%{shen: 300_000}),
             %{family: "武当派"},
             cfg_tu()
           ) == {:ok, "taiji-quan/tu", 3000}
  end

  test "inquiry_grant/3：wudang 太极图 — 多项 min_levels 任一不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_player(%{
                 shen: 300_000,
                 skills: %{
                   "taiji-quan" => 249,
                   "taiji-shengong" => 420,
                   "taiji-jian" => 420,
                   "taoism" => 400,
                   "force" => 420
                 }
               }),
               %{family: "武当派"},
               cfg_tu()
             )
  end

  # ask_skill7：缠字诀 — taiji-jian/chan (gongxian>=300, shen>=80000, taiji-jian>=80)
  defp cfg_chan do
    %{
      "perform_id" => "taiji-jian/chan",
      "skill" => "taiji-jian",
      "min_levels" => %{"taiji-jian" => 80},
      "min_gongxian" => 300,
      "min_shen" => 80_000,
      "cost_gongxian" => 300
    }
  end

  test "inquiry_grant/3：wudang 缠字诀（taiji-jian/chan）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_chan()) ==
             {:ok, "taiji-jian/chan", 300}
  end

  # ask_skill8：随字诀 — taiji-jian/sui (gongxian>=200, shen>=80000, taiji-jian>=60)
  defp cfg_sui do
    %{
      "perform_id" => "taiji-jian/sui",
      "skill" => "taiji-jian",
      "min_levels" => %{"taiji-jian" => 60},
      "min_gongxian" => 200,
      "min_shen" => 80_000,
      "cost_gongxian" => 200
    }
  end

  test "inquiry_grant/3：wudang 随字诀（taiji-jian/sui）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_sui()) ==
             {:ok, "taiji-jian/sui", 200}
  end

  # ask_skill9：驾字诀 — taiji-jian/jia (gongxian>=600, shen>=100000, taiji-jian>=150)
  defp cfg_jia do
    %{
      "perform_id" => "taiji-jian/jia",
      "skill" => "taiji-jian",
      "min_levels" => %{"taiji-jian" => 150},
      "min_gongxian" => 600,
      "min_shen" => 100_000,
      "cost_gongxian" => 600
    }
  end

  test "inquiry_grant/3：wudang 驾字诀（taiji-jian/jia）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_jia()) ==
             {:ok, "taiji-jian/jia", 600}
  end

  # ask_skill10：剑轮岚转 — taiji-jian/zhuan (gongxian>=800, shen>=120000, taiji-jian>=160)
  defp cfg_zhuan do
    %{
      "perform_id" => "taiji-jian/zhuan",
      "skill" => "taiji-jian",
      "min_levels" => %{"taiji-jian" => 160},
      "min_gongxian" => 800,
      "min_shen" => 120_000,
      "cost_gongxian" => 800
    }
  end

  test "inquiry_grant/3：wudang 剑轮岚转（taiji-jian/zhuan）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_zhuan()) ==
             {:ok, "taiji-jian/zhuan", 800}
  end

  # ask_skill11：真武除邪 — taiji-jian/zhenwu (gongxian>=2000, shen>=120000, taiji-jian>=180)
  defp cfg_zhenwu do
    %{
      "perform_id" => "taiji-jian/zhenwu",
      "skill" => "taiji-jian",
      "min_levels" => %{"taiji-jian" => 180},
      "min_gongxian" => 2000,
      "min_shen" => 120_000,
      "cost_gongxian" => 2000
    }
  end

  test "inquiry_grant/3：wudang 真武除邪（taiji-jian/zhenwu）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudang_player(), %{family: "武当派"}, cfg_zhenwu()) ==
             {:ok, "taiji-jian/zhenwu", 2000}
  end

  test "inquiry_grant/3：wudang 11 门 ask_skill 已会则不重复授予（can_perform 分支）" do
    for cfg <- [
          cfg_dian(),
          cfg_zhen(),
          cfg_yin(),
          cfg_ji(),
          cfg_zhan(),
          cfg_tu(),
          cfg_chan(),
          cfg_sui(),
          cfg_jia(),
          cfg_zhuan(),
          cfg_zhenwu()
        ] do
      perform_id = Map.get(cfg, "perform_id")
      stats = wudang_player(%{performs: MapSet.new([perform_id])})

      assert {:error, "这一招你不是已经会了吗？\n"} =
               Kantele.SectMaster.inquiry_grant(stats, %{family: "武当派"}, cfg)
    end
  end

  # ---- wudu_qiyunao ask_skill1..3 → perform_id 门槛测试（kungfu/class/wudu/qiyunao.c） ----
  # 每门绝招：family=五毒教 + skill >= 1 + gongxian >= N + min_levels 达标 → {:ok, perform_id, cost}
  # TODO：LPC 还校验 shen <= -20000/-35000/-40000（足够邪恶），与 inquiry_grant 的
  #       `shen >= min_shen` 方向相反，本批 min_shen 置 sentinel（不拦），后续另设 max_shen。

  defp wudu_player(overrides \\ %{}) do
    Map.merge(
      %Stats{
        skills: %{
          "xiewei-bian" => 180,
          "tianchan-zhang" => 200,
          "wusheng-zhao" => 200,
          "force" => 220,
          "wudu_xinfa" => 220,
          "xiuluo_yinshagong" => 180,
          "dodge" => 180,
          "jinshe_youshenbu" => 180,
          "strike" => 200,
          "claw" => 200,
          "parry" => 200,
          "sword" => 200,
          "jinwu_goufa" => 180,
          "whip" => 180,
          "throwing" => 180,
          "literate" => 100,
          "poison" => 250,
          "wudu_qishu" => 250,
          "martial_cognize" => 200
        },
        gongxian: 5000,
        shen: -200_000,
        performs: MapSet.new()
      },
      overrides
    )
  end

  # ask_skill1：腾蛇诀 — xiewei-bian/tengshe (xiewei-bian>=100, gongxian>=100)
  defp cfg_tengshe do
    %{
      "perform_id" => "xiewei-bian/tengshe",
      "skill" => "xiewei-bian",
      "min_levels" => %{"xiewei-bian" => 100},
      "min_gongxian" => 100,
      "min_shen" => -99_999_999,
      "cost_gongxian" => 100
    }
  end

  test "inquiry_grant/3：wudu 腾蛇诀（xiewei-bian/tengshe）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudu_player(), %{family: "五毒教"}, cfg_tengshe()) ==
             {:ok, "xiewei-bian/tengshe", 100}
  end

  test "inquiry_grant/3：wudu 腾蛇诀 — 非同门拒绝" do
    assert {:error, "你我并非同门，何来讨教绝招之说？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player() |> Map.from_struct() |> Map.put(:family, "峨眉派"),
               %{family: "五毒教"},
               cfg_tengshe()
             )
  end

  test "inquiry_grant/3：wudu 腾蛇诀 — 未习核心技能拒绝" do
    assert {:error, "你连xiewei-bian都没学，还谈什么绝招可言？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{
                 skills: %{
                   "xiewei-bian" => 0,
                   "tianchan-zhang" => 200,
                   "wusheng-zhao" => 200,
                   "force" => 220
                 }
               }),
               %{family: "五毒教"},
               cfg_tengshe()
             )
  end

  test "inquiry_grant/3：wudu 腾蛇诀 — gongxian 不足拒绝" do
    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{gongxian: 99}),
               %{family: "五毒教"},
               cfg_tengshe()
             )
  end

  test "inquiry_grant/3：wudu 腾蛇诀 — min_levels 不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{
                 skills: %{
                   "xiewei-bian" => 99,
                   "tianchan-zhang" => 200,
                   "wusheng-zhao" => 200,
                   "force" => 220
                 }
               }),
               %{family: "五毒教"},
               cfg_tengshe()
             )
  end

  # ask_skill2：毒蟾掌 — tianchan-zhang/chan (tianchan-zhang>=120, force>=150, gongxian>=200)
  #
  # 名字必须带门派前缀：武当也有 `cfg_chan/0`（taiji-jian/chan）。同名两个 0 元子句时
  # Elixir 只有第一个能命中，五毒的这几条测试会静默拿到武当的配置。
  defp cfg_tianchan do
    %{
      "perform_id" => "tianchan-zhang/chan",
      "skill" => "tianchan-zhang",
      "min_levels" => %{"tianchan-zhang" => 120, "force" => 150},
      "min_gongxian" => 200,
      "min_shen" => -99_999_999,
      "cost_gongxian" => 200
    }
  end

  test "inquiry_grant/3：wudu 毒蟾掌（tianchan-zhang/chan）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudu_player(), %{family: "五毒教"}, cfg_tianchan()) ==
             {:ok, "tianchan-zhang/chan", 200}
  end

  test "inquiry_grant/3：wudu 毒蟾掌 — 非同门拒绝" do
    assert {:error, "你我并非同门，何来讨教绝招之说？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player() |> Map.from_struct() |> Map.put(:family, "峨眉派"),
               %{family: "五毒教"},
               cfg_tianchan()
             )
  end

  test "inquiry_grant/3：wudu 毒蟾掌 — 未习核心技能拒绝" do
    assert {:error, "你连tianchan-zhang都没学，还谈什么绝招可言？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{
                 skills: %{
                   "xiewei-bian" => 180,
                   "tianchan-zhang" => 0,
                   "wusheng-zhao" => 200,
                   "force" => 220
                 }
               }),
               %{family: "五毒教"},
               cfg_tianchan()
             )
  end

  test "inquiry_grant/3：wudu 毒蟾掌 — gongxian 不足拒绝" do
    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{gongxian: 199}),
               %{family: "五毒教"},
               cfg_tianchan()
             )
  end

  test "inquiry_grant/3：wudu 毒蟾掌 — min_levels 不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{
                 skills: %{
                   "xiewei-bian" => 180,
                   "tianchan-zhang" => 119,
                   "wusheng-zhao" => 200,
                   "force" => 150
                 }
               }),
               %{family: "五毒教"},
               cfg_tianchan()
             )
  end

  # ask_skill3：夺命连环 — wusheng-zhao/lian (wusheng-zhao>=120, force>=150, gongxian>=300)
  defp cfg_lian do
    %{
      "perform_id" => "wusheng-zhao/lian",
      "skill" => "wusheng-zhao",
      "min_levels" => %{"wusheng-zhao" => 120, "force" => 150},
      "min_gongxian" => 300,
      "min_shen" => -99_999_999,
      "cost_gongxian" => 300
    }
  end

  test "inquiry_grant/3：wudu 夺命连环（wusheng-zhao/lian）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(wudu_player(), %{family: "五毒教"}, cfg_lian()) ==
             {:ok, "wusheng-zhao/lian", 300}
  end

  test "inquiry_grant/3：wudu 夺命连环 — 非同门拒绝" do
    assert {:error, "你我并非同门，何来讨教绝招之说？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player() |> Map.from_struct() |> Map.put(:family, "峨眉派"),
               %{family: "五毒教"},
               cfg_lian()
             )
  end

  test "inquiry_grant/3：wudu 夺命连环 — 未习核心技能拒绝" do
    assert {:error, "你连wusheng-zhao都没学，还谈什么绝招可言？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{
                 skills: %{
                   "xiewei-bian" => 180,
                   "tianchan-zhang" => 200,
                   "wusheng-zhao" => 0,
                   "force" => 220
                 }
               }),
               %{family: "五毒教"},
               cfg_lian()
             )
  end

  test "inquiry_grant/3：wudu 夺命连环 — gongxian 不足拒绝" do
    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{gongxian: 299}),
               %{family: "五毒教"},
               cfg_lian()
             )
  end

  test "inquiry_grant/3：wudu 夺命连环 — min_levels 不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudu_player(%{
                 skills: %{
                   "xiewei-bian" => 180,
                   "tianchan-zhang" => 200,
                   "wusheng-zhao" => 119,
                   "force" => 150
                 }
               }),
               %{family: "五毒教"},
               cfg_lian()
             )
  end

  test "inquiry_grant/3：wudu 3 门 ask_skill 已会则不重复授予（can_perform 分支）" do
    for cfg <- [cfg_tengshe(), cfg_tianchan(), cfg_lian()] do
      perform_id = Map.get(cfg, "perform_id")
      stats = wudu_player(%{performs: MapSet.new([perform_id])})

      assert {:error, "这一招你不是已经会了吗？\n"} =
               Kantele.SectMaster.inquiry_grant(stats, %{family: "五毒教"}, cfg)
    end
  end

  # ---- wudang 4 门 ask_skill（ask_me → perform_id）门槛测试（kungfu/class/wudang/{shan,xi,yin,yu}.c）----
  # guxu/qingxu：give_item 走 GiveItem 处理器，不经过 SectMaster.inquiry_grant，此处不测试。
  # shen 方向：武当派正派，LPC 校验 shen >= 正阈值，与 inquiry_grant 的 shen >= min_shen 一致。

  # 武当演武玩家模板：基础技能全达标，shen/gongxian 充足
  defp wudang_ask_me_player(overrides \\ %{}) do
    Map.merge(
      wudang_player(),
      overrides
    )
  end

  # 张翠山「谁与争锋」— yitian-zhang/zheng (yitian-zhang>=120, gongxian>=200, shen>=12000)
  defp cfg_shan do
    %{
      "perform_id" => "yitian-zhang/zheng",
      "skill" => "yitian-zhang",
      "min_levels" => %{"yitian-zhang" => 120},
      "min_gongxian" => 200,
      "min_shen" => 12000,
      "cost_gongxian" => 200
    }
  end

  test "inquiry_grant/3：wudang 谁与争锋（yitian-zhang/zheng）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(
             wudang_ask_me_player(%{skills: Map.put(wudang_player().skills, "yitian-zhang", 150)}),
             %{family: "武当派"},
             cfg_shan()
           ) == {:ok, "yitian-zhang/zheng", 200}
  end

  test "inquiry_grant/3：wudang 谁与争锋 — 非同门拒绝" do
    assert {:error, "你我并非同门，何来讨教绝招之说？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player() |> Map.from_struct() |> Map.put(:family, "峨眉派"),
               %{family: "武当派"},
               cfg_shan()
             )
  end

  test "inquiry_grant/3：wudang 谁与争锋 — 未习核心技能拒绝" do
    assert {:error, "你连yitian-zhang都没学，还谈什么绝招可言？\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player(%{skills: Map.put(wudang_player().skills, "yitian-zhang", 0)}),
               %{family: "武当派"},
               cfg_shan()
             )
  end

  # 下面三条要验的是 gongxian / shen / min_levels 分支，必须先把 `skill` 学会，
  # 否则会先撞上「你连yitian-zhang都没学」（`inquiry_grant/3` 的检查顺序：
  # 已会 → 同门 → 必修技能 → 贡献 → 杀气 → min_levels）。
  defp shan_learned(overrides) do
    wudang_ask_me_player(
      Map.put(overrides, :skills, Map.put(wudang_player().skills, "yitian-zhang", 150))
    )
  end

  test "inquiry_grant/3：wudang 谁与争锋 — gongxian 不足拒绝" do
    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(
               shan_learned(%{gongxian: 199}),
               %{family: "武当派"},
               cfg_shan()
             )
  end

  test "inquiry_grant/3：wudang 谁与争锋 — shen 不足拒绝" do
    assert {:error, "这一招太过阴恨，若被你用去我恐怕不放心！\n"} =
             Kantele.SectMaster.inquiry_grant(
               shan_learned(%{shen: 11999}),
               %{family: "武当派"},
               cfg_shan()
             )
  end

  test "inquiry_grant/3：wudang 谁与争锋 — min_levels 不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player(%{
                 skills: Map.put(wudang_player().skills, "yitian-zhang", 119)
               }),
               %{family: "武当派"},
               cfg_shan()
             )
  end

  # 张松溪「乱环诀」— xuanxu-dao/huan (xuanxu-dao>=100, gongxian>=150, shen>=10000)
  defp cfg_xi do
    %{
      "perform_id" => "xuanxu-dao/huan",
      "skill" => "xuanxu-dao",
      "min_levels" => %{"xuanxu-dao" => 100},
      "min_gongxian" => 150,
      "min_shen" => 10000,
      "cost_gongxian" => 150
    }
  end

  test "inquiry_grant/3：wudang 乱环诀（xuanxu-dao/huan）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(
             wudang_ask_me_player(%{skills: Map.put(wudang_player().skills, "xuanxu-dao", 150)}),
             %{family: "武当派"},
             cfg_xi()
           ) == {:ok, "xuanxu-dao/huan", 150}
  end

  test "inquiry_grant/3：wudang 乱环诀 — gongxian 不足拒绝" do
    # 同样先学会 xuanxu-dao，否则先撞「你连xuanxu-dao都没学」
    assert {:error, "你为本派效力还不够，这招我先不忙传你。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player(%{
                 gongxian: 149,
                 skills: Map.put(wudang_player().skills, "xuanxu-dao", 150)
               }),
               %{family: "武当派"},
               cfg_xi()
             )
  end

  test "inquiry_grant/3：wudang 乱环诀 — min_levels 不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player(%{skills: Map.put(wudang_player().skills, "xuanxu-dao", 99)}),
               %{family: "武当派"},
               cfg_xi()
             )
  end

  # 殷梨亭「柔月穿空」— raozhi-roujian/chuankong (raozhi-roujian>=100, force>=150, gongxian>=250, shen>=15000)
  #
  # 名字不能叫 `cfg_yin/0`：武当 taiji-quan/yin 已占该名，同名子句只有第一个能命中。
  defp cfg_chuankong do
    %{
      "perform_id" => "raozhi-roujian/chuankong",
      "skill" => "raozhi-roujian",
      "min_levels" => %{"raozhi-roujian" => 100, "force" => 150},
      "min_gongxian" => 250,
      "min_shen" => 15000,
      "cost_gongxian" => 250
    }
  end

  test "inquiry_grant/3：wudang 柔月穿空（raozhi-roujian/chuankong）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(
             wudang_ask_me_player(%{
               skills: Map.put(wudang_player().skills, "raozhi-roujian", 150)
             }),
             %{family: "武当派"},
             cfg_chuankong()
           ) == {:ok, "raozhi-roujian/chuankong", 250}
  end

  test "inquiry_grant/3：wudang 柔月穿空 — 多项 min_levels 任一不足拒绝" do
    assert {:error, "你的修为还不够，练高了再来吧。\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player(%{
                 skills: %{
                   "taiji-shengong" => 420,
                   "taiji-quan" => 420,
                   "taiji-jian" => 420,
                   "taoism" => 400,
                   "force" => 149,
                   "raozhi-roujian" => 150
                 }
               }),
               %{family: "武当派"},
               cfg_chuankong()
             )
  end

  # 俞莲舟「绝户神抓」— huzhua-shou/juehu (huzhua-shou>=120, force>=180, gongxian>=400, shen>=100000)
  defp cfg_yu do
    %{
      "perform_id" => "huzhua-shou/juehu",
      "skill" => "huzhua-shou",
      "min_levels" => %{"huzhua-shou" => 120, "force" => 180},
      "min_gongxian" => 400,
      "min_shen" => 100_000,
      "cost_gongxian" => 400
    }
  end

  test "inquiry_grant/3：wudang 绝户神抓（huzhua-shou/juehu）全门槛达标 → {:ok}" do
    assert Kantele.SectMaster.inquiry_grant(
             wudang_ask_me_player(%{skills: Map.put(wudang_player().skills, "huzhua-shou", 150)}),
             %{family: "武当派"},
             cfg_yu()
           ) == {:ok, "huzhua-shou/juehu", 400}
  end

  test "inquiry_grant/3：wudang 绝户神抓 — shen 不足拒绝" do
    # 先学会 huzhua-shou，否则先撞「你连huzhua-shou都没学」
    assert {:error, "这一招太过阴恨，若被你用去我恐怕不放心！\n"} =
             Kantele.SectMaster.inquiry_grant(
               wudang_ask_me_player(%{
                 shen: 99999,
                 skills: Map.put(wudang_player().skills, "huzhua-shou", 150)
               }),
               %{family: "武当派"},
               cfg_yu()
             )
  end

  test "inquiry_grant/3：wudang 4 门 ask_skill 已会则不重复授予（can_perform 分支）" do
    for cfg <- [cfg_shan(), cfg_xi(), cfg_chuankong(), cfg_yu()] do
      perform_id = Map.get(cfg, "perform_id")
      stats = wudang_ask_me_player(%{performs: MapSet.new([perform_id])})

      assert {:error, "这一招你不是已经会了吗？\n"} =
               Kantele.SectMaster.inquiry_grant(stats, %{family: "武当派"}, cfg)
    end
  end
end

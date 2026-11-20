defmodule Kantele.SectMasterTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster

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

  test "recruit_gate?/3：max_shen 上限（shen 超过上限拒绝，未配置不拦）" do
    # max_shen = 50000，student shen = 20000 <= 50000 → 通过
    assert :ok =
             Kantele.SectMaster.recruit_gate?(
               teacher(%{meta: %{apprentice: %{max_shen: 50_000}}}),
               teacher_student()
             )

    # student shen = 60000 > 50000 → 拒绝
    high_shen_student = %{
      meta: %{
        family: %{name: "武当派"},
        stats: %{combat_exp: 300_000, shen: 60_000, skills: %{"sword" => 40}}
      }
    }

    assert {:error, "你心慈手软，杀气不够重，本派不收。\n"} =
             Kantele.SectMaster.recruit_gate?(
               teacher(%{meta: %{apprentice: %{max_shen: 50_000}}}),
               high_shen_student
             )

    # max_shen 为 nil（未配置）时不拦截，shen 再高也通过
    assert :ok =
             Kantele.SectMaster.recruit_gate?(
               teacher(%{meta: %{apprentice: %{min_shen: 0}}}),
               %{
                 meta: %{
                   family: %{name: "武当派"},
                   stats: %{combat_exp: 300_000, shen: 999_999, skills: %{"sword" => 40}}
                 }
               }
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

  # ---- min_dex 身法门槛（hu/hufei.c ask_skill5「飞天神行」query_dex() < 33） ----

  defp dex_config(overrides \\ %{}) do
    Map.merge(Map.put(neili_config(), "min_dex", 33), overrides)
  end

  defp dex_player(overrides \\ %{}) do
    neili_player(Map.merge(%{dex: 33, max_neili: 3600}, overrides))
  end

  test "inquiry_grant/3：min_dex 达标（LPC dex >= 33）" do
    assert {:ok, "guzhuo-zhang/zhuo", 600} =
             Kantele.SectMaster.inquiry_grant(dex_player(), %{}, dex_config())
  end

  test "inquiry_grant/3：min_dex 不足即拒（hufei.c ask_skill5 身法分支）" do
    assert {:error, "你的身法太差，还需多加练习。\n"} =
             Kantele.SectMaster.inquiry_grant(dex_player(%{dex: 32}), %{}, dex_config())
  end

  test "inquiry_grant/3：缺 min_dex 键不拦（老配置不受影响）" do
    assert {:ok, "guzhuo-zhang/zhuo", 600} =
             Kantele.SectMaster.inquiry_grant(
               dex_player(%{dex: 0}),
               %{},
               Map.delete(dex_config(), "min_dex")
             )
  end

  test "inquiry_grant/3：dex_deny 覆盖身法不足缺省文案" do
    assert {:error, "身法不行，练好轻功再来。"} =
             Kantele.SectMaster.inquiry_grant(
               dex_player(%{dex: 20}),
               %{},
               dex_config(%{"dex_deny" => "身法不行，练好轻功再来。"})
             )
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

  # ---- 少林移植 #639：性别门控 + permit_recruit 三条 ----

  defp shaolin_gate(overrides \\ %{}) do
    Map.merge(
      %{
        family: "少林派",
        min_shen: 0,
        min_exp: 0,
        min_skills: %{},
        no_recruit: [],
        gender: "男性",
        permit_recruit: true
      },
      overrides
    )
  end

  defp shaolin_student(overrides \\ %{}) do
    %{
      meta:
        Map.merge(
          %{
            family: nil,
            env: %{gender: "男性"},
            stats: %{combat_exp: 2_000_000, shen: 100, skills: %{}}
          },
          overrides
        )
    }
  end

  test "recruit_gate? 性别门控：女性拒绝（LPC 清无/清为文案）" do
    assert {:error, "阿弥陀佛！女施主呀，贫僧可不敢开这等玩笑啊。\n"} =
             Kantele.SectMaster.recruit_gate?(
               nil,
               shaolin_student(%{env: %{gender: "女性"}}),
               shaolin_gate()
             )
  end

  test "recruit_gate? 性别门控：无性拒绝（LPC 公公文案）" do
    assert {:error, "阿弥陀佛！这位公公，你还是回去伺候皇上吧。\n"} =
             Kantele.SectMaster.recruit_gate?(
               nil,
               shaolin_student(%{env: %{gender: "无性"}}),
               shaolin_gate()
             )
  end

  test "recruit_gate? 性别门控：男性且无门派/无背叛记录 → :ok" do
    assert :ok = Kantele.SectMaster.recruit_gate?(nil, shaolin_student(), shaolin_gate())
  end

  test "recruit_gate? permit_recruit：detach/少林派 拒绝" do
    student = shaolin_student(%{env: %{gender: "男性", detach: %{少林派: 1}}})

    assert {:error, "你反反复复，唉！怎么一心向佛？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, shaolin_gate())
  end

  test "recruit_gate? permit_recruit：betrayer/少林派 拒绝" do
    student = shaolin_student(%{env: %{gender: "男性", betrayer: %{少林派: true}}})

    assert {:error, "你反反复复，唉！怎么一心向佛？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, shaolin_gate())
  end

  test "recruit_gate? permit_recruit：betrayer.times>0 拒绝" do
    student = shaolin_student(%{env: %{gender: "男性", betrayer: %{times: 1}}})

    assert {:error, "你大逆不道，私自判师，不能容于少林！\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, shaolin_gate())
  end

  test "recruit_gate? permit_recruit：已入他派拒绝" do
    student = shaolin_student(%{family: %{name: "武当派"}})

    assert {:error, "你已经名师指点，为何不下苦功，反而来我们少林寺呢？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, shaolin_gate())
  end

  test "recruit_gate? 向后兼容：无 gender/permit 字段的旧门派门控不受影响" do
    old_gate = %{family: "武当派", min_shen: 0, min_exp: 0, min_skills: %{}, no_recruit: []}
    assert :ok = Kantele.SectMaster.recruit_gate?(nil, shaolin_student(), old_gate)
  end

  # ---- Task #644：gate_order 控制 permit_recruit 与 gender 先后顺序 ----

  test "recruit_gate? gate_order=gender_first：性别先于 permit_recruit（清无 LPC qing-wu.c）" do
    # 女性 + detach/少林派：gender_first 时先被性别拒，不会走到 permit_recruit
    gate = Map.put(shaolin_gate(), :gate_order, "gender_first")
    student = shaolin_student(%{env: %{gender: "女性", detach: %{"少林派" => 1}}})

    assert {:error, "阿弥陀佛！女施主呀，贫僧可不敢开这等玩笑啊。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, gate)
  end

  test "recruit_gate? gate_order=gender_first：男性 + detach/少林派 走 permit_recruit 拒绝" do
    gate = Map.put(shaolin_gate(), :gate_order, "gender_first")
    student = shaolin_student(%{env: %{gender: "男性", detach: %{"少林派" => 1}}})

    assert {:error, "你反反复复，唉！怎么一心向佛？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, gate)
  end

  test "recruit_gate? gate_order=permit_first（缺省）：permit_recruit 先于性别（清为/清法 LPC）" do
    # 女性 + detach/少林派：permit_first 时先被 permit_recruit 拒
    student = shaolin_student(%{env: %{gender: "女性", detach: %{"少林派" => 1}}})

    assert {:error, "你反反复复，唉！怎么一心向佛？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, shaolin_gate())
  end

  test "recruit_gate? gate_order 缺省为 permit_first" do
    gate = shaolin_gate()  # 不设 gate_order
    assert Map.get(gate, :gate_order) == nil  # UCL 不设时为 nil，recruit_gate? 内部默认 "permit_first"
    student = shaolin_student(%{env: %{gender: "男性", detach: %{"少林派" => 1}}})

    assert {:error, "你反反复复，唉！怎么一心向佛？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, gate)
  end
end

defmodule Kantele.SectMasterDamoGateTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster

  # 达摩祖师 attempt_apprentice 11 项门槛（少林移植 #626/#636）。
  # 每项单独破坏一个条件，验证拒绝文案与「int<35 只提示不 return」原版行为。
  defp damo_gate(overrides \\ %{}) do
    Map.merge(
      %{
        family: "少林派",
        permit_recruit: true,
        exact_family: true,
        require_class: "bonze",
        exact_generation: 36,
        min_int: 35,
        max_wpk: 3,
        min_skills: %{buddhism: 180, dodge: 180, force: 180, parry: 180},
        min_exp: 1_000_000
      },
      overrides
    )
  end

  defp damo_student(overrides \\ %{}) do
    %{
      meta:
        Map.merge(
          %{
            family: %{name: "少林派", generation: 36, class: "bonze"},
            env: %{gender: "男性"},
            combat: %{WPK: 0},
            stats: %{
              int: 50,
              combat_exp: 2_000_000,
              shen: 0,
              skills: %{buddhism: 200, dodge: 200, force: 200, parry: 200}
            }
          },
          overrides
        )
    }
  end

  test "11 项全过 → :ok" do
    assert :ok = Kantele.SectMaster.recruit_gate?(nil, damo_student(), damo_gate())
  end

  test "#2 permit_recruit 先判：已入他派走少林通用拒绝文案" do
    student = damo_student(%{family: %{name: "武当派", generation: 36, class: "bonze"}})

    assert {:error, "你已经名师指点，为何不下苦功，反而来我们少林寺呢？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, damo_gate())
  end

  test "#2 无门派（permit_recruit 不拦）→ 素无来往" do
    student = damo_student(%{family: nil})

    assert {:error, "大侠与本派素无来往，不知此话从何谈起？\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, damo_gate())
  end

  test "#3 俗家弟子 → 不能在寺内学艺" do
    student = damo_student(%{family: %{name: "少林派", generation: 36}})

    assert {:error, "大侠是俗家弟子，不能在寺内学艺。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, damo_gate())
  end

  test "#4 辈分 35 → 贫僧哪里敢当" do
    student = damo_student(%{family: %{name: "少林派", generation: 35, class: "bonze"}})

    assert {:error, "大侠，贫僧哪里敢当！\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, damo_gate())
  end

  test "#5 int<35 只提示不 return（原版缺 return）" do
    stats = %{
      int: 30,
      combat_exp: 2_000_000,
      shen: 0,
      skills: %{buddhism: 200, dodge: 200, force: 200, parry: 200}
    }

    assert {:ok, "大侠悟性仍有不足，需要进一步锻炼才能领悟更高深的佛法。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, damo_student(%{stats: stats}), damo_gate())
  end

  test "#5 提示后仍被 #6 WPK 拒绝 → 两条文案按 LPC 顺序合并" do
    stats = %{
      int: 30,
      combat_exp: 2_000_000,
      shen: 0,
      skills: %{buddhism: 200, dodge: 200, force: 200, parry: 200}
    }

    student = damo_student(%{stats: stats, combat: %{WPK: 4}})

    assert {:error,
            "大侠悟性仍有不足，需要进一步锻炼才能领悟更高深的佛法。\n" <>
              "大侠杀戮心太重，不适合继续学习武功。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, damo_gate())
  end

  test "#6 WPK=4 → 杀戮心太重" do
    assert {:error, "大侠杀戮心太重，不适合继续学习武功。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, damo_student(%{combat: %{WPK: 4}}), damo_gate())
  end

  test "#7 buddhism<180 → 禅宗心法不够" do
    stats = %{
      int: 50,
      combat_exp: 2_000_000,
      shen: 0,
      skills: %{buddhism: 179, dodge: 200, force: 200, parry: 200}
    }

    assert {:error, _} =
             Kantele.SectMaster.recruit_gate?(nil, damo_student(%{stats: stats}), damo_gate())
  end

  test "#11 combat_exp<1000000 → 实战经验欠缺" do
    stats = %{
      int: 50,
      combat_exp: 999_999,
      shen: 0,
      skills: %{buddhism: 200, dodge: 200, force: 200, parry: 200}
    }

    assert {:error, "你经验尚浅，武功未成，师父未同意收你为徒。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, damo_student(%{stats: stats}), damo_gate())
  end

  test "UCL *_deny 覆写文案" do
    student = damo_student(%{combat: %{WPK: 4}})
    gate = damo_gate(%{wpk_deny: "施主杀气未消，且慢。"})

    assert {:error, "施主杀气未消，且慢。\n"} =
             Kantele.SectMaster.recruit_gate?(nil, student, gate)
  end

  describe "华山派门控（Task #740）" do
    defp huashan_player(overrides \\ %{}) do
      %Stats{
        skills: %{"huashan-jian" => 160, "kuangfeng-jian" => 140, "force" => 150, "dodge" => 180},
        gongxian: 0,
        shen: 0,
        potential: 100,
        learned_points: 0,
        int: 40,
        performs: MapSet.new()
      }
      |> Map.put(:family, "华山派")
      |> Map.put(:max_neili, 1900)
      |> Map.merge(overrides)
    end

    test "inquiry_grant：剑宗上界先于技能下界判定，保持 LPC 气宗歧途文案" do
      config = %{
        "perform_id" => "huashan-jian/long",
        "skill" => "huashan-jian",
        "min_levels" => %{"huashan-jian" => 150, "force" => 150},
        "max_skill_levels" => %{"force" => 205},
        "max_neili_cap" => 2000,
        "force_cap_deny" => "内功入了气宗歧途。\n",
        "neili_cap_deny" => "内力太深。\n"
      }

      assert {:ok, "huashan-jian/long", 0} =
               SectMaster.inquiry_grant(huashan_player(), %{family: "华山派"}, config)

      assert {:error, "内功入了气宗歧途。\n"} =
               SectMaster.inquiry_grant(
                 huashan_player(%{skills: %{"huashan-jian" => 10, "force" => 206}}),
                 %{family: "华山派"},
                 config
               )

      assert {:error, "内力太深。\n"} =
               SectMaster.inquiry_grant(huashan_player(%{max_neili: 2001}), %{family: "华山派"}, config)
    end

    test "recruit_gate?：性别/侠义/逐技能文案可由 UCL 覆写" do
      student = %{
        meta: %{
          family: %{name: "华山派"},
          env: %{gender: "女性"},
          stats: %{combat_exp: 1_000_000, shen: 0, skills: %{"huashan-jian" => 139, "huashan-xinfa" => 150}}
        }
      }

      gate = %{
        family: "华山派",
        gender: "男性",
        gender_deny: "我不收女徒弟，你还是去找我师妹吧！",
        min_shen: 20_000,
        min_shen_deny: "你行侠仗义的事还做得不够！",
        min_skills: %{"huashan-jian" => 140, "huashan-xinfa" => 140},
        min_skills_deny: %{"huashan-jian" => "你华山剑法还不够熟练！"}
      }

      assert {:error, "我不收女徒弟，你还是去找我师妹吧！\n"} =
               SectMaster.recruit_gate?(nil, student, gate)

      male = put_in(student, [:meta, :env, :gender], "男性")

      assert {:error, "你行侠仗义的事还做得不够！\n"} =
               SectMaster.recruit_gate?(nil, male, gate)

      loyal = put_in(male, [:meta, :stats, :shen], 20_000)

      assert {:error, "你华山剑法还不够熟练！\n"} =
               SectMaster.recruit_gate?(nil, loyal, gate)
    end

    test "teach_skill_grant：狂风快剑按 int 分档 + 剑宗上界 + 逐技能拒绝文案" do
      config = %{
        "skill" => "kuangfeng-jian",
        "family" => "华山派",
        "level_source" => "int",
        "level_pivot" => 30,
        "level_factor" => 2,
        "max_neili_cap" => 2000,
        "max_skill_levels" => %{"force" => 205},
        "min_skill_levels" => %{"sword" => 120, "dodge" => 180},
        "min_skill_deny" => %{"sword" => "剑法不足", "dodge" => "轻功不足"}
      }

      player = huashan_player(%{int: 40, skills: %{"sword" => 120, "dodge" => 180}})
      assert {:ok, "kuangfeng-jian", 50} = SectMaster.teach_skill_grant(player, %{family: "华山派"}, config)

      assert {:error, "轻功不足"} =
               SectMaster.teach_skill_grant(
                 huashan_player(%{skills: %{"sword" => 120, "dodge" => 179}}),
                 %{family: "华山派"},
                 config
               )

      assert {:error, "你的内功修为已入了旁门，不能再学本门剑术。\n"} =
               SectMaster.teach_skill_grant(
                 huashan_player(%{skills: %{"sword" => 120, "dodge" => 180, "force" => 206}}),
                 %{family: "华山派"},
                 config
               )
    end

    test "teach_skill_grant：已知/异门顺序（known_first）+ 冲灵剑法 lv/10" do
      config = %{
        "skill" => "chongling-jian",
        "family" => "华山派",
        "gate_order" => "known_first",
        "level_source" => "huashan-jian",
        "level_divisor" => 10,
        "min_skill_levels" => %{"huashan-jian" => 100},
        "maxed" => "你不是已经会了吗？"
      }

      player = huashan_player(%{skills: %{"huashan-jian" => 145}})
      assert {:ok, "chongling-jian", 14} = SectMaster.teach_skill_grant(player, %{family: "华山派"}, config)

      known = huashan_player(%{skills: %{"huashan-jian" => 145, "chongling-jian" => 1}})

      assert {:error, "你不是已经会了吗？"} =
               SectMaster.teach_skill_grant(known, %{family: "丐帮"}, config)
    end

    test "unlock_perform：独孤九剑破式的潜能/已会门槛" do
      config = %{
        "perform_id" => "dugu-jiujian/po",
        "skill" => "dugu-jiujian",
        "min_potential" => 10,
        "skill_deny" => "你会独孤九剑么？",
        "potential_deny" => "潜能不够。"
      }

      assert {:error, "你会独孤九剑么？"} =
               SectMaster.unlock_perform(huashan_player(), config)

      learned = huashan_player(%{skills: %{"dugu-jiujian" => 100}, potential: 9})
      assert {:exhausted, "潜能不够。"} = SectMaster.unlock_perform(learned, config)

      enough = huashan_player(%{skills: %{"dugu-jiujian" => 100}, potential: 100})
      assert {:ok, "dugu-jiujian/po", 10} = SectMaster.unlock_perform(enough, config)

      known = Map.put(enough, :performs, MapSet.new(["dugu-jiujian/po"]))

      assert {:error, "你不是已经学会这一式了么？\n"} =
               SectMaster.unlock_perform(known, config)
    end
  end

  describe "绝情谷门控（Task #745）" do
    defp jueqing_player(overrides \\ %{}) do
      %Stats{
        skills: %{"tiexian-quan" => 80, "force" => 100, "qin" => 0},
        gongxian: 0,
        shen: -70_000,
        performs: MapSet.new()
      }
      |> Map.put(:family, "绝情谷")
      |> Map.merge(overrides)
    end

    defp chi_gate do
      %{
        family: "绝情谷",
        permit_recruit: true,
        reject_master_name: "公孙止",
        reject_master_name_deny: "我裘千尺可不收公孙止那恶贼的徒弟。",
        max_shen: -60_000,
        max_shen_deny: "我裘千尺可不收心慈手软的人做徒弟。",
        no_min_shen: true,
        min_exp: 400_000,
        min_exp_deny: "你这点能力怎能继承我的衣钵？"
      }
    end

    test "recruit_gate?：仇家师父先于侠义/经验判定，逐技能拒绝文案由 UCL 覆写" do
      student = %{
        meta: %{
          family: %{name: "绝情谷", master_name: "公孙止"},
          stats: %{shen: -70_000, combat_exp: 500_000, skills: %{}}
        }
      }

      assert {:error, "我裘千尺可不收公孙止那恶贼的徒弟。\n"} =
               SectMaster.recruit_gate?(nil, student, chi_gate())

      family = Map.put(student.meta.family, :master_name, "旁人")
      clean = %{student | meta: %{student.meta | family: family}}

      assert :ok = SectMaster.recruit_gate?(nil, clean, chi_gate())

      low_exp = put_in(clean.meta.stats.combat_exp, 100)

      assert {:error, "你这点能力怎能继承我的衣钵？\n"} =
               SectMaster.recruit_gate?(nil, low_exp, chi_gate())
    end

    test "inquiry_grant：lpc_masterd 顺序先神、再贡献、再技能等级" do
      config = %{
        "perform_id" => "tiexian-quan/jia",
        "skill" => "tiexian-quan",
        "gate_order" => "lpc_masterd",
        "min_levels" => %{"tiexian-quan" => 60, "force" => 80},
        "min_gongxian" => 100,
        "cost_gongxian" => 100,
        "max_shen" => -60_000,
        "max_shen_deny" => "哼！像你这样的心慈手软之辈，又能干成什么大事？\n",
        "gongxian_deny" => "你为绝情谷作出的贡献不够，这招暂时还不能传你。\n",
        "level_deny" => %{
          "tiexian-quan" => "你对铁线拳的了解还不够，尚且无法领悟此招。\n",
          "force" => "你目前的内功火候不足，下去练练再来吧。\n"
        }
      }

      npc = %{family: "绝情谷"}

      # 神/贡献/技能三项同时不满足 → 先报负神文案（缺省顺序会先报技能）
      bad = jueqing_player(%{shen: 0, skills: %{}, gongxian: 0})

      assert {:error, "哼！像你这样的心慈手软之辈，又能干成什么大事？\n"} =
               SectMaster.inquiry_grant(bad, npc, config)

      no_gx = jueqing_player(%{gongxian: 0})

      assert {:error, "你为绝情谷作出的贡献不够，这招暂时还不能传你。\n"} =
               SectMaster.inquiry_grant(no_gx, npc, config)

      low_skill = jueqing_player(%{gongxian: 100, skills: %{"tiexian-quan" => 50, "force" => 100}})

      assert {:error, "你对铁线拳的了解还不够，尚且无法领悟此招。\n"} =
               SectMaster.inquiry_grant(low_skill, npc, config)

      ok = jueqing_player(%{gongxian: 100})
      assert {:ok, "tiexian-quan/jia", 100} = SectMaster.inquiry_grant(ok, npc, config)
    end

    test "inquiry_grant：lpc_masterd 顺序同门先于已学会" do
      config = %{
        "perform_id" => "tiexian-quan/jia",
        "skill" => "tiexian-quan",
        "gate_order" => "lpc_masterd",
        "family_deny" => "大侠与我绝情谷素无渊源，不知此话从何说起。\n",
        "maxed" => "这招你不是已经会了么，还缠着我做甚？\n"
      }

      outsider =
        jueqing_player(%{
          family: "丐帮",
          performs: MapSet.new(["tiexian-quan/jia"])
        })

      assert {:error, "大侠与我绝情谷素无渊源，不知此话从何说起。\n"} =
               SectMaster.inquiry_grant(outsider, %{family: "绝情谷"}, config)
    end
  end

  describe "昆仑派门控（Task #752）" do
    test "teachable?/3：no_teach_deny 按技能返回 LPC 原文拒教文案" do
      teacher = %{
        meta: %{
          family: %{name: "昆仑派"},
          teach: %{
            family: "昆仑派",
            no_teach: ["liangyi-shengong", "zhengliangyi-jian"],
            no_teach_deny: %{
              "liangyi-shengong" => "两仪神功需得掌门人亲自传授。",
              "zhengliangyi-jian" => "正两仪剑法乃本门神功，需要掌门人亲自传授。"
            }
          },
          stats: %{skills: %{"liangyi-shengong" => 130, "zhengliangyi-jian" => 130}}
        }
      }

      student = %{
        meta: %{
          family: %{name: "昆仑派"},
          stats: %{skills: %{"liangyi-shengong" => 10, "zhengliangyi-jian" => 10}}
        }
      }

      assert {:error, "两仪神功需得掌门人亲自传授。\n"} =
               SectMaster.teachable?(teacher, student, "liangyi-shengong")

      assert {:error, "正两仪剑法乃本门神功，需要掌门人亲自传授。\n"} =
               SectMaster.teachable?(teacher, student, "zhengliangyi-jian")
    end

    test "recruit_gate?：permit_recruit 三句可由 UCL 逐字覆写" do
      gate = %{
        family: "昆仑派",
        permit_recruit: true,
        betray_sect_deny: "亏你还有脸回我昆仑山？给我滚开！",
        betray_times_deny: "阁下不忠不信，我最痛恨你这种人了。",
        other_family_deny: "阁下既有了名师指点，还来我们昆仑派做什么？"
      }

      betrayed_sect = %{
        meta: %{
          env: %{betrayer: %{"昆仑派" => 1}},
          stats: %{shen: 20_000, combat_exp: 400_000, skills: %{}}
        }
      }

      assert {:error, "亏你还有脸回我昆仑山？给我滚开！\n"} =
               SectMaster.recruit_gate?(nil, betrayed_sect, gate)

      betrayed_times = %{
        meta: %{
          env: %{betrayer: %{times: 1}},
          stats: %{shen: 20_000, combat_exp: 400_000, skills: %{}}
        }
      }

      assert {:error, "阁下不忠不信，我最痛恨你这种人了。\n"} =
               SectMaster.recruit_gate?(nil, betrayed_times, gate)

      other_sect = %{
        meta: %{
          family: %{name: "武当派"},
          stats: %{shen: 20_000, combat_exp: 400_000, skills: %{}}
        }
      }

      assert {:error, "阁下既有了名师指点，还来我们昆仑派做什么？\n"} =
               SectMaster.recruit_gate?(nil, other_sect, gate)
    end

    test "recruit_gate?：hard_min_int 是硬门，不与达摩 min_int 提示语义混用" do
      gate = %{
        family: "昆仑派",
        min_shen: 10_000,
        min_exp: 400_000,
        hard_min_int: 38,
        int_deny:
          "高深的武功以及精深的技艺都需灵性极高的人才能悟其真谛，不致背道而驰。\n我看大侠还是先回去多读点书吧。"
      }

      student = fn int ->
        %{
          meta: %{
            stats: %{
              shen: 20_000,
              combat_exp: 400_000,
              int: int,
              skills: %{"liangyi-shengong" => 100, "zhengliangyi-jian" => 100}
            }
          }
        }
      end

      assert {:error, "高深的武功以及精深的技艺都需灵性极高的人才能悟其真谛，不致背道而驰。\n我看大侠还是先回去多读点书吧。\n"} =
               SectMaster.recruit_gate?(nil, student.(37), gate)

      assert :ok = SectMaster.recruit_gate?(nil, student.(38), gate)
    end

    test "inquiry_grant：lpc_kunlun 按 level_order 判定，dex 早于最终技能等级" do
      config = %{
        "perform_id" => "zhengliangyi-jian/wu",
        "skill" => "zhengliangyi-jian",
        "gate_order" => "lpc_kunlun",
        "min_gongxian" => 1200,
        "cost_gongxian" => 1200,
        "min_levels" => %{
          "force" => 220,
          "dodge" => 220,
          "dex" => 45,
          "zhengliangyi-jian" => 160
        },
        "level_order" => ["force", "dodge", "dex", "zhengliangyi-jian"],
        "level_deny" => %{
          "force" => "你的内功火候不足，学不了这一招。",
          "dodge" => "你的轻功火候不足，学不了这一招。",
          "dex" => "你的身法实在太差，学不了这一招。",
          "zhengliangyi-jian" => "你的正两仪剑法修为还不够，自己下去练练再来吧。"
        }
      }

      npc = %{family: "昆仑派"}

      player = fn overrides ->
        %{
          family: "昆仑派",
          gongxian: 1200,
          skills: %{
            "force" => 100,
            "dodge" => 250,
            "zhengliangyi-jian" => 100
          },
          dex: 44,
          performs: MapSet.new()
        }
        |> Map.merge(overrides)
      end

      # force / dex / 技能等级三项同时不足 → LPC 先报内功
      assert {:error, "你的内功火候不足，学不了这一招。\n"} =
               SectMaster.inquiry_grant(player.(%{force: 100}), npc, config)

      # force 达标后 → LPC 先报身法，而不是最终剑法等级
      force_ok =
        player.(%{})
        |> put_in([:skills, "force"], 220)

      assert {:error, "你的身法实在太差，学不了这一招。\n"} =
               SectMaster.inquiry_grant(force_ok, npc, config)

      ok =
        force_ok
        |> put_in([:dex], 45)
        |> put_in([:skills, "zhengliangyi-jian"], 160)

      assert {:ok, "zhengliangyi-jian/wu", 1200} =
               SectMaster.inquiry_grant(ok, npc, config)
    end

    test "inquiry_grant：lpc_kunlun 的 requires_perform 位于贡献之后、等级之前" do
      config = %{
        "perform_id" => "qiankun-jian/ni",
        "skill" => "qiankun-jian",
        "gate_order" => "lpc_kunlun",
        "min_gongxian" => 1800,
        "cost_gongxian" => 1800,
        "requires_perform" => "qiankun-jian/qian",
        "requires_perform_deny" => "要学此招，必须先通晓「乾坤劲」的奥秘。",
        "min_levels" => %{"force" => 300, "qiankun-jian" => 180},
        "level_order" => ["force", "qiankun-jian"],
        "level_deny" => %{"force" => "你的内功火候不足，学不了这一招！"}
      }

      npc = %{family: "昆仑派"}
      base = %{
        family: "昆仑派",
        gongxian: 1800,
        skills: %{"force" => 100, "qiankun-jian" => 100},
        performs: MapSet.new()
      }

      assert {:error, "你对本派所作出的贡献不够，这一招我暂时还不能传你。\n"} =
               SectMaster.inquiry_grant(%{base | gongxian: 0}, npc, config)

      assert {:error, "要学此招，必须先通晓「乾坤劲」的奥秘。\n"} =
               SectMaster.inquiry_grant(base, npc, config)

      ready = %{
        base
        | skills: %{"force" => 300, "qiankun-jian" => 180},
          performs: MapSet.new(["qiankun-jian/qian"])
      }

      assert {:ok, "qiankun-jian/ni", 1800} = SectMaster.inquiry_grant(ready, npc, config)
    end
  end

  describe "逍遥派 apprentice 门控（Task #804）" do
    defp xy_student(stats_overrides \\ %{}) do
      stats =
        %{
          per: 30,
          int: 30,
          combat_exp: 200_000,
          shen: 0,
          skills: %{"xiaoyao-xinfa" => 50}
        }
        |> Map.merge(stats_overrides)

      %{meta: %{family: %{name: "逍遥派"}, env: %{}, stats: stats}}
    end

    test "min_per 容貌硬门：per<28 按 xiaoyao.h 文案拒绝" do
      gate = %{
        family: "逍遥派",
        permit_recruit: true,
        min_per: 28,
        per_deny: "容貌不足\n",
        hard_min_int: 27,
        int_deny: "悟性不足\n",
        min_skills: %{"xiaoyao-xinfa" => 30},
        min_skills_deny: %{"xiaoyao-xinfa" => "心法不足\n"},
        betray_sect_deny: "叛门\n",
        betray_times_deny: "判师\n",
        other_family_deny: "他派\n"
      }

      assert {:error, "容貌不足\n"} = SectMaster.recruit_gate?(nil, xy_student(%{per: 27}), gate)
      assert :ok = SectMaster.recruit_gate?(nil, xy_student(%{per: 28}), gate)
    end

    test "gate_order=lpc_xiaoyao：悟性硬门先于经验门（苏星河顺序）" do
      student = xy_student(%{int: 20, combat_exp: 100_000})
      gate = recruit_gate_fixture()

      assert {:error, "你经验尚浅，武功未成，师父未同意收你为徒。\n"} =
               SectMaster.recruit_gate?(nil, student, gate)

      assert {:error, "悟性不足\n"} =
               SectMaster.recruit_gate?(nil, student, Map.put(gate, :gate_order, "lpc_xiaoyao"))
    end

    test "gate_order=lpc_wuyazi：任一内功 OR 门 → force/dodge → int → exp" do
      gate = %{
        family: "逍遥派",
        permit_recruit: true,
        gate_order: "lpc_wuyazi",
        any_min_skills: %{
          "xiaoyao-xinfa" => 130,
          "xiaowuxiang" => 130,
          "beiming-shengong" => 130
        },
        any_min_skills_deny: "本门内功不足\n",
        min_skills: %{"force" => 130, "dodge" => 130},
        min_skills_deny: %{"force" => "内功不足\n", "dodge" => "轻功不足\n"},
        hard_min_int: 40,
        int_deny: "悟性不足\n",
        min_exp: 500_000,
        min_exp_deny: "经验不足\n"
      }

      assert {:error, "本门内功不足\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 xy_student(%{
                   skills: %{"xiaoyao-xinfa" => 100, "force" => 200, "dodge" => 200}
                 }),
                 gate
               )

      assert {:error, "内功不足\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 xy_student(%{
                   int: 20,
                   combat_exp: 100_000,
                   skills: %{"beiming-shengong" => 200, "force" => 100, "dodge" => 200}
                 }),
                 gate
               )

      assert :ok =
               SectMaster.recruit_gate?(
                 nil,
                 xy_student(%{
                   int: 41,
                   combat_exp: 600_000,
                   skills: %{"xiaowuxiang" => 150, "force" => 150, "dodge" => 150}
                 }),
                 gate
               )
    end

    defp recruit_gate_fixture do
      %{
        family: "逍遥派",
        permit_recruit: true,
        min_per: 28,
        per_deny: "容貌不足\n",
        hard_min_int: 27,
        int_deny: "悟性不足\n",
        min_exp: 200_000,
        min_skills: %{"xiaoyao-xinfa" => 30},
        min_skills_deny: %{"xiaoyao-xinfa" => "心法不足\n"},
        betray_sect_deny: "叛门\n",
        betray_times_deny: "判师\n",
        other_family_deny: "他派\n"
      }
    end
  end

  describe "星宿派 grant 有序门控（Task #811）" do
    defp xx_player(overrides \\ %{}) do
      %Stats{
        skills: %{},
        gongxian: 500,
        shen: -20_000,
        performs: MapSet.new()
      }
      |> Map.put(:family, "星宿派")
      |> Map.put(:max_neili, 1200)
      |> Map.merge(overrides)
    end

    defp xx_config(extra \\ %{}) do
      Map.merge(
        %{
          "perform_id" => "chousui-zhang/shi",
          "skill" => "chousui-zhang",
          "gate_order" => "lpc_masterd",
          "max_shen" => -10_000,
          "min_gongxian" => 500,
          "cost_gongxian" => 500,
          "level_deny" => %{
            "force" => "你对基本内功的了解还不够，尚且无法领悟此招。\n",
            "poison" => "你对基本毒技的了解还不够，尚且无法领悟此招。\n"
          }
        },
        extra
      )
    end

    test "level_order 固定 sk1→force→poison 顺序，不随 map 枚举漂移" do
      config =
        xx_config(%{
          "min_levels" => %{
            "chousui-zhang" => 140,
            "force" => 120,
            "poison" => 150,
            "throwing" => 120
          },
          "level_order" => ["chousui-zhang", "force", "poison", "throwing"]
        })

      player =
        xx_player(%{
          skills: %{
            "chousui-zhang" => 140,
            "force" => 100,
            "poison" => 100,
            "throwing" => 120
          }
        })

      assert {:error, "你对基本内功的了解还不够，尚且无法领悟此招。\n"} =
               Kantele.SectMaster.inquiry_grant(player, %{family: "星宿派"}, config)

      ready = %{player | skills: %{player.skills | "force" => 120}}
      assert {:error, "你对基本毒技的了解还不够，尚且无法领悟此招。\n"} =
               Kantele.SectMaster.inquiry_grant(ready, %{family: "星宿派"}, config)
    end

    test "min_force 是 masterd.c 独立字段：sk2 force 130 满足后再判 force 80" do
      config =
        xx_config(%{
          "perform_id" => "chanhun-suo/duo",
          "skill" => "chanhun-suo",
          "min_levels" => %{"chanhun-suo" => 100, "force" => 130},
          "level_order" => ["chanhun-suo", "force"],
          "min_force" => 80
        })

      low = xx_player(%{skills: %{"chanhun-suo" => 100, "force" => 129}})

      assert {:error, "你对基本内功的了解还不够，尚且无法领悟此招。\n"} =
               Kantele.SectMaster.inquiry_grant(low, %{family: "星宿派"}, config)

      ok = xx_player(%{skills: %{"chanhun-suo" => 100, "force" => 130}})
      assert {:ok, "chanhun-suo/duo", 500} =
               Kantele.SectMaster.inquiry_grant(ok, %{family: "星宿派"}, config)
    end

    test "未配置 level_order / min_force 的老 masterd 配置零回归" do
      config =
        xx_config(%{"min_levels" => %{"chousui-zhang" => 140, "force" => 120}})

      player = xx_player(%{skills: %{"chousui-zhang" => 140, "force" => 119}})

      assert {:error, _reason} =
               Kantele.SectMaster.inquiry_grant(player, %{family: "星宿派"}, config)
    end
  end

  describe "玄冥谷门控（Task #817）" do
    @describetag :xuanming_engine
    test "min_dodge 独立门位于 force 之后、内力之前（masterd.c b[\"dodge\"]）" do
      config = %{
        "perform_id" => "dulong-shenzhua/bao",
        "skill" => "dulong-shenzhua",
        "gate_order" => "lpc_masterd",
        "max_shen" => -38000,
        "min_gongxian" => 420,
        "cost_gongxian" => 420,
        "min_levels" => %{"dulong-shenzhua" => 100},
        "level_order" => ["dulong-shenzhua"],
        "min_dodge" => 150,
        "min_force" => 80
      }

      base = %Stats{
        skills: %{"dulong-shenzhua" => 100, "dodge" => 149, "force" => 120},
        gongxian: 420,
        shen: -40_000,
        performs: MapSet.new()
      }
      |> Map.put(:family, "玄冥谷")

      assert {:error, "你目前的轻功火候不足，下去练练再来吧。\n"} =
               Kantele.SectMaster.inquiry_grant(base, %{family: "玄冥谷"}, config)

      ready = %{base | skills: %{base.skills | "dodge" => 150}}
      assert {:ok, "dulong-shenzhua/bao", 420} =
               Kantele.SectMaster.inquiry_grant(ready, %{family: "玄冥谷"}, config)
    end

    test "gate_order=lpc_xuanming：技能门先于经验门（百损道人/鹿杖客顺序）" do
      gate = %{
        family: "玄冥谷",
        permit_recruit: true,
        gate_order: "lpc_xuanming",
        no_min_shen: true,
        max_shen: -35000,
        max_shen_deny: "杀气门\n",
        min_skills: %{"minggu-xinfa" => 160, "strike" => 160},
        min_skills_deny: %{
          "minggu-xinfa" => "冥谷心法不足\n",
          "strike" => "掌法不足\n"
        },
        min_exp: 500000,
        min_exp_deny: "经验不足\n",
        betray_sect_deny: "叛门\n",
        betray_times_deny: "判师\n",
        other_family_deny: "他派\n"
      }

      student = fn skills, exp ->
        %{
          meta: %{
            family: %{name: "玄冥谷"},
            env: %{},
            stats: %{shen: -40_000, combat_exp: exp, skills: skills}
          }
        }
      end

      assert {:error, "冥谷心法不足\n"} =
               Kantele.SectMaster.recruit_gate?(
                 nil,
                 student.(%{"minggu-xinfa" => 159, "strike" => 160}, 100_000),
                 gate
               )

      assert {:error, "经验不足\n"} =
               Kantele.SectMaster.recruit_gate?(
                 nil,
                 student.(%{"minggu-xinfa" => 160, "strike" => 160}, 499_999),
                 gate
               )

      assert :ok =
               Kantele.SectMaster.recruit_gate?(
                 nil,
                 student.(%{"minggu-xinfa" => 160, "strike" => 160}, 500_000),
                 gate
               )
    end
  end
end

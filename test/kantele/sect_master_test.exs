defmodule Kantele.SectMasterTest do
  use ExUnit.Case, async: true

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
            teach_skills: %{"sword" => %{max: 40, gongxian: 2}, "force" => %{max: 30, gongxian: 2}},
            no_teach: []
          },
          apprentice: %{family: "武当派", min_shen: 20_000, min_exp: 300_000, min_skills: %{}, no_recruit: []},
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

    assert Kantele.SectMaster.teachable?(npc_teacher, %{meta: %{family: student_family_map}}, "taiji-quan") ==
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
      meta: %{family: %{name: "武当派"}, stats: %{combat_exp: 100_000, shen: 100, skills: %{"force" => 20}}}
    }

    assert {:error, "你根基尚浅，这几样本事还未练成，先回去打好基础再来吧。\n"} =
             Kantele.SectMaster.recruit_gate?(strict, weak_student)
  end

  test "detach_penalty?/2：同门派叛师惩罚（family map 入参）" do
    assert {:penalty, _msg} =
             Kantele.SectMaster.detach_penalty?(%{name: "武当派"}, %{name: "武当派"})

    assert {:noop} =
             Kantele.SectMaster.detach_penalty?(%{name: "武当派"}, %{name: "峨眉派"})
  end

  defp teacher_student do
    %{
      meta: %{
        family: %{name: "武当派"},
        stats: %{combat_exp: 300_000, shen: 20_000, skills: %{"sword" => 40}}
      }
    }
  end
end
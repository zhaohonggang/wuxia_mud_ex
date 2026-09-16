defmodule Kantele.SectMasterTest do
  use ExUnit.Case, async: true

  # 形状镜像 loader.ex:495-508 parse_teach 产出（纯函数入参形状）
  # + sect_master.ex 真身贫口（@35 teachable?/3 @55 recruit_gate?/3 @72 detach_penalty?/2）

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
        combat_exp: 300_000,
        shen: 20_000
      }
      },
      overrides
    )
  end

  defp outsider_student do
    %{
      meta: %{
        family: "武当派",
        family_name: "武当派",
        combat_exp: 100_000,
        shen: 100
      }
    }
  end

  defp other_sect_student do
    %{
      meta: %{
        family: "峨眉派",
        family_name: "峨眉派",
        combat_exp: 100_000,
        shen: 100
      }
    }
  end

  test "teachable?/3：同门派非嫡传被 prevent_learn? 链拦" do
    assert Kantele.SectMaster.teachable?(teacher(), outsider_student(), "sword") ==
             {:error, "你非本门嫡传，老夫不便传授。\n"}
  end

  test "teachable?/3：异门派由更高层收徒门槛把（此处贫口只负责本门门槛）" do
    assert Kantele.SectMaster.teachable?(teacher(), other_sect_student(), "sword") == :ok
  end

  test "recruit_gate?/3：shen/exp 真门槛" do
    assert {:error, _msg} = Kantele.SectMaster.recruit_gate?(teacher(), outsider_student())
    assert :ok = Kantele.SectMaster.recruit_gate?(teacher(%{meta: %{combat_exp: 300_000, shen: 20_000}}), outsider_student())
  end

  test "detach_penalty?/2：同门派叛师惩罚" do
    assert {:penalty, _msg} = Kantele.SectMaster.detach_penalty?("武当派", "武当派")
    assert {:noop} = Kantele.SectMaster.detach_penalty?("武当派", "峨眉派")
  end
end

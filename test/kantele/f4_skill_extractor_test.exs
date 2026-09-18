defmodule Kantele.F4SkillExtractorTest do
  use ExUnit.Case

  Code.require_file("../../scripts/translate_skill.exs", __DIR__)

  alias Scripts.TranslateSkill

  @fixtures Path.expand("../../scripts/fixtures/kungfu/skill", __DIR__)

  defp c(skill), do: Path.join(@fixtures, skill <> ".c")

  describe "招式表解析（静态/动态分流）" do
    test "huashan-jian：6 式静态 + 1 式动态，name 归一为 skill_name" do
      d = TranslateSkill.extract(c("huashan-jian"))

      assert d.skill == "huashan-jian"
      assert length(d.actions) == 6
      assert d.dynamic_actions == 1

      first = hd(d.actions)

      assert first["skill_name"] == "有凤来仪"
      assert first["action"] =~ "有凤来仪"
      assert first["force"] == 70
      assert first["attack"] == 10
      assert first["parry"] == 5
      assert first["dodge"] == 10
      assert first["damage"] == 30
      assert first["lvl"] == 0
      assert first["damage_type"] == "刺伤"
    end

    test "huashan-jian：负 dodge 保留为负值" do
      # 第 6 式（白虹贯日）dodge 为 -20
      assert Enum.any?(TranslateSkill.extract(c("huashan-jian")).actions, &(&1["dodge"] == -20))
    end

    test "chousui-zhang：5 式静态，dmage 拼写归一为 damage，缺 name 则无 skill_name" do
      d = TranslateSkill.extract(c("chousui-zhang"))

      assert length(d.actions) == 5
      assert d.dynamic_actions == 1

      first = hd(d.actions)

      refute Map.has_key?(first, "skill_name")
      assert first["damage"] == 32
      assert first["lvl"] == 0
      assert first["damage_type"] == "瘀伤"
    end

    test "无招式表返回空表" do
      tmp = Path.join(System.tmp_dir!(), "f4_skill_empty_#{System.unique_integer([:positive])}.c")
      on_exit(fn -> File.rm(tmp) end)
      File.write!(tmp, "inherit SKILL;\nint valid_learn(object me) { return 1; }\n")

      d = TranslateSkill.extract(tmp)

      assert d.actions == []
      assert d.dynamic_actions == 0
    end
  end

  describe "valid_enable / practice_skill / 钩子" do
    test "huashan-jian 事实" do
      d = TranslateSkill.extract(c("huashan-jian"))

      assert d.valid_enable == ["parry", "sword"]
      assert d.practice_cost == %{qi: 50, neili: 31}

      for flag <- ~w(valid_learn hit_ob valid_effect perform_action_file) do
        assert flag in d.flags
      end
    end

    test "chousui-zhang 事实（含 valid_combine）" do
      d = TranslateSkill.extract(c("chousui-zhang"))

      assert d.valid_enable == ["parry", "strike"]
      assert d.practice_cost == %{qi: 65, neili: 55}
      assert "valid_combine" in d.flags
      assert "valid_learn" in d.flags
    end

    test "practice_cost 只取 practice_skill 函数体，不误纳 hit_ob 的 add" do
      # huashan-jian 的 hit_ob 有 add("neili", -60)，不得污染 practice_cost
      assert TranslateSkill.extract(c("huashan-jian")).practice_cost == %{qi: 50, neili: 31}
    end
  end

  describe "骨架生成" do
    test "模块名 huashan-jian → Kantele.Combat.Skills.Generated.HuashanJian" do
      assert TranslateSkill.camel("huashan-jian") == "HuashanJian"
    end

    test "render_skeleton 含 @actions / id / valid_enable / practice_cost / query_action" do
      skel = TranslateSkill.render_skeleton(TranslateSkill.extract(c("huashan-jian")))

      assert skel =~ "defmodule Kantele.Combat.Skills.Generated.HuashanJian"
      assert skel =~ ~s{def id(), do: "huashan-jian"}
      assert skel =~ ~s(usage in ["parry", "sword"])
      assert skel =~ "def practice_cost(), do: %{qi: 50, neili: 31}"
      assert skel =~ "def query_action(level, rng \\\\ &:rand.uniform/1) do"
      assert skel =~ "Kantele.Combat.Skill.pick_action(@actions, level, rng)"
      assert skel =~ ~s("skill_name" => "有凤来仪")
      assert skel =~ "TODO(migrate)"
      assert String.valid?(skel)
      refute skel =~ <<0xEF, 0xBF, 0xBD>>
    end

    test "run 落到 <skill>.ex + _summary.md，内容与 render_skeleton 一致且幂等" do
      out = Path.join(System.tmp_dir!(), "f4_skill_out_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf(out) end)

      stats = TranslateSkill.run(@fixtures, out)

      assert "huashan_jian.ex" in stats.written
      assert "chousui_zhang.ex" in stats.written
      assert stats.count == 2

      rendered = TranslateSkill.render_skeleton(TranslateSkill.extract(c("huashan-jian")))
      assert File.read!(Path.join(out, "huashan_jian.ex")) == rendered

      assert File.read!(Path.join(out, "_summary.md")) =~ "| huashan-jian | 6 | 1 |"

      # 幂等：二次 run 不应重写文件
      assert TranslateSkill.run(@fixtures, out).written == []
    end
  end
end

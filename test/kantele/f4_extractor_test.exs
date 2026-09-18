defmodule Kantele.F4ExtractorTest do
  use ExUnit.Case

  Code.require_file("../../scripts/translate_perform.exs", __DIR__)

  alias Scripts.TranslatePerform

  @fixtures Path.expand("../../scripts/fixtures/kungfu/skill", __DIR__)

  defp c(skill, move), do: Path.join([@fixtures, skill, move <> ".c"])

  describe "分类（F_SSERVER + perform|exert 签名）" do
    test "huashan-jian/jie 是 perform（F_SSERVER）" do
      assert TranslatePerform.classify(c("huashan-jian", "jie")) == {:perform, "F_SSERVER"}
    end

    test "chousui-zhang/dan 是 perform（F_SSERVER）" do
      assert TranslatePerform.classify(c("chousui-zhang", "dan")) == {:perform, "F_SSERVER"}
    end

    test "force/power 是 exert（F_CLEAN_UP）" do
      assert TranslatePerform.classify(c("force", "power")) == {:exert, "F_CLEAN_UP"}
    end

    test "非招式文件跳过去" do
      tmp = Path.join(System.tmp_dir!(), "f4_skip_#{System.unique_integer([:positive])}.c")
      on_exit(fn -> File.rm(tmp) end)
      File.write!(tmp, "int foo(object me) { return 1; }\n")
      assert TranslatePerform.classify(tmp) == {:skip, false}
    end
  end

  describe "事实抽取" do
    test "jie：门槛/武器/资源/cost/busy" do
      d = TranslatePerform.extract(c("huashan-jian", "jie"))

      assert d.kind == :perform
      assert d.skill == "huashan-jian"
      assert {"huashan-jian", "30"} in d.level_gates
      assert {"sword", "huashan-jian"} in d.map_gates
      assert {"neili", "60"} in d.resource_gates
      assert {"neili", "-50"} in d.add_costs
      assert Enum.any?(d.busy_lines, &(&1 =~ "start_busy(level / 22 + 2)"))
      assert d.first_fail =~ "外功中没有这种功能"
    end

    test "dan：多技能门槛/prepared/远程伤害/毒/消耗" do
      d = TranslatePerform.extract(c("chousui-zhang", "dan"))

      assert {"throwing", "190"} in d.level_gates
      assert {"lvl", "chousui-zhang"} in d.assign_refs
      assert {"lvp", "poison"} in d.assign_refs
      assert {"lvl", "120"} in d.var_gates
      assert {"lvp", "180"} in d.var_gates
      assert {"strike", "chousui-zhang"} in d.map_gates
      assert {"strike", "chousui-zhang"} in d.prepared_gates
      assert {"max_neili", "1800"} in d.resource_gates
      assert {"neili", "300"} in d.resource_gates
      assert {"neili", "-220"} in d.add_costs
      assert d.affect_by == ["fire_poison"]
      assert d.remote_damage == true
      assert d.title == "炼心弹"
    end

    test "yinfeng-dao/jue：标题末字含 0x80，u 标志下不截断" do
      d = TranslatePerform.extract(c("yinfeng-dao", "jue"))

      assert d.title == "绝杀"
      assert String.valid?(d.title)
      assert String.valid?(TranslatePerform.render_skeleton(d))
      refute TranslatePerform.render_skeleton(d) =~ <<0xEF, 0xBF, 0xBD>>

      raw = File.read!(c("yinfeng-dao", "jue"))
      byte_pat = ~r/#define\s+\w+\s*"「"\s*\w*\s*"([^"「」]+)/
      assert [_, truncated] = Regex.run(byte_pat, raw)
      refute String.valid?(truncated)
    end

    test "power：内力量清零/双门槛/战斗中忙乱" do
      d = TranslatePerform.extract(c("force", "power"))

      assert d.kind == :exert
      assert d.skill == "force"
      assert {"force", "200"} in d.level_gates
      assert {"skill", "martial-cognize"} in d.assign_refs
      assert {"skill", "120"} in d.var_gates
      assert {"neili", "100"} in d.resource_gates
      assert {"neili", "0"} in d.set_flags
      assert Enum.any?(d.busy_lines, &(&1 =~ "start_busy(3)"))
      assert d.first_fail =~ "你只能提升自己的战斗力"
    end
  end

  describe "骨架生成（批量管线输出）" do
    test "模块名 huashan-jian/jie → Kantele.Combat.Skills.Performs.HuashanJian.Jie" do
      assert TranslatePerform.module_name("huashan-jian", "jie") ==
               "Kantele.Combat.Skills.Performs.HuashanJian.Jie"
    end

    test "run 落到 performs/<skill>/<move>.ex，内容与 render_skeleton 一致" do
      out =
        Path.join(System.tmp_dir!(), "f4_out_#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf(out) end)

      stats = TranslatePerform.run(@fixtures, out)

      assert Path.join("huashan_jian", "jie.ex") in stats.written
      assert Path.join("chousui_zhang", "dan.ex") in stats.written
      assert Path.join("force", "power.ex") in stats.written

      rendered = TranslatePerform.render_skeleton(TranslatePerform.extract(c("force", "power")))
      assert File.read!(Path.join([out, "force", "power.ex"])) == rendered

      # 生成骨架必须是合法 UTF-8（中文标题/文案不得被清洗逻辑改坏）
      assert String.valid?(rendered)
      refute rendered =~ <<0xEF, 0xBF, 0xBD>>

      skel = rendered
      assert skel =~ "defmodule Kantele.Combat.Skills.Performs.Force.Power"
      assert skel =~ "TODO(migrate)"

      # 幂等：二次 run 不应重写文件
      stats2 = TranslatePerform.run(@fixtures, out)
      assert stats2.written == []
    end
  end
end
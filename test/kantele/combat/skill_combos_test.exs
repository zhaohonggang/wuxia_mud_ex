defmodule Kantele.Combat.SkillCombosTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.SkillCombos

  describe "SkillCombos 数据模块" do
    test "size 返回声明 valid_combine 的技能数量" do
      assert SkillCombos.size() >= 1
    end

    test "pair_count 返回组合关系总数" do
      assert SkillCombos.pair_count() >= 1
    end

    test "all 返回全部组合表" do
      assert is_map(SkillCombos.all())
    end

    test "for 返回未定义技能的空列表" do
      assert SkillCombos.for("nonexistent-skill") == []
    end

    test "taiji-quan 允许与 wudang-zhang 组合" do
      assert "wudang-zhang" in SkillCombos.for("taiji-quan")
    end

    test "taiji-quan 允许与 paiyun-shou 组合" do
      assert "paiyun-shou" in SkillCombos.for("taiji-quan")
    end

    test "valid_combine? 按方向查询（taiji-quan -> wudang-zhang 为 true）" do
      assert SkillCombos.valid_combine?("taiji-quan", "wudang-zhang") == true
    end

    test "valid_combine? 不匹配时返回 false" do
      assert SkillCombos.valid_combine?("taiji-quan", "huashan-jian") == false
    end

    test "valid_combine? 对未定义技能返回 false" do
      assert SkillCombos.valid_combine?("nonexistent", "anything") == false
    end

    test "valid_combine? 有方向性（wudang-zhang -> taiji-quan 可能为 false，取决于源定义）" do
      # LPC 语义：SKILL_D(skill)->valid_combine(other) 是单方向判定
      # 当前只有 taiji-quan 定义 valid_combine，所以反向为 false
      assert SkillCombos.valid_combine?("wudang-zhang", "taiji-quan") == false
    end
  end
end

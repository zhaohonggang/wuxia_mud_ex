defmodule Kantele.Combat.SkillsQingliangJianTest do
  @moduledoc """
  清凉剑法学习门槛迁移（C 相位，qingliang-jian 真缺口补齐）。

  对照 `kungfu/skill/qingliang-jian.c`：
  - valid_learn: max_neili>=500 / shaolin-xinfa>=50 / sword>=50；
  - practice_skill 扣 qi 35（不耗内力，须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QingliangJian

  defp stats(shaolin, sword, qingliang),
    do: %{skills: %{"shaolin-xinfa" => shaolin, "sword" => sword, "qingliang-jian" => qingliang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=500 / shaolin-xinfa>=50 / sword>=50）" do
    test "max_neili < 500 被拒（内力不够）" do
      assert QingliangJian.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "shaolin-xinfa < 50 被拒（少林心法火候太浅）" do
      assert QingliangJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的少林心法火候太浅。\n"}
    end

    test "sword < 50 被拒（基本剑法火候尚浅）" do
      assert QingliangJian.valid_learn(stats(100, 10, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候尚浅。\n"}
    end

    test "三项全满足则放行" do
      assert QingliangJian.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert QingliangJian.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert QingliangJian.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / 不耗内力）" do
    test "返回 LPC 一致的消耗" do
      assert QingliangJian.practice_cost() == %{qi: 35, neili: 0}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qingliang-jian") == QingliangJian
    end
  end
end

defmodule Kantele.Combat.SkillsQixingJianTest do
  @moduledoc """
  七星剑法学习门槛迁移（C 相位，qixing-jian 真缺口补齐）。

  对照 `kungfu/skill/qixing-jian.c`：
  - valid_learn: max_neili>=100 / sword>=10 / sword>=qixing-jian；
  - practice_skill 扣 qi 35 / neili 33（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QixingJian

  defp stats(sword, qixing),
    do: %{skills: %{"sword" => sword, "qixing-jian" => qixing}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / sword>=10 / sword>=qixing-jian）" do
    test "max_neili < 100 被拒（内力修为太差）" do
      assert QixingJian.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为太差，无法学习七星剑法。\n"}
    end

    test "sword < 10 被拒（基本剑法修为不够）" do
      assert QixingJian.valid_learn(stats(5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法修为不够，无法学习七星剑法。\n"}
    end

    test "sword < qixing-jian 被拒（基本剑法水平有限）" do
      assert QixingJian.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的七星剑法。\n"}
    end

    test "三项全满足则放行" do
      assert QixingJian.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert QixingJian.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert QixingJian.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / neili 33）" do
    test "返回 LPC 一致的消耗" do
      assert QixingJian.practice_cost() == %{qi: 35, neili: 33}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qixing-jian") == QixingJian
    end
  end
end

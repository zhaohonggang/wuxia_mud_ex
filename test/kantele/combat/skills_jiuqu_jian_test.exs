defmodule Kantele.Combat.SkillsJiuquJianTest do
  @moduledoc """
  九曲剑法学习门槛迁移（C 相位，jiuqu-jian 真缺口补齐）。

  对照 `kungfu/skill/jiuqu-jian.c`：
  - valid_learn: max_neili>=300 / force>=100 / sword>=60 / sword>=jiuqu-jian；
  - practice_skill 扣 qi 40 / neili 50（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JiuquJian

  defp stats(force, sword, jiuqu),
    do: %{skills: %{"force" => force, "sword" => sword, "jiuqu-jian" => jiuqu}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=300 / force>=100 / sword>=60 / sword>=jiuqu-jian）" do
    test "max_neili < 300 被拒（内力不够）" do
      assert JiuquJian.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够，没有办法练九曲剑法。\n"}
    end

    test "force < 100 被拒（内功火候太浅）" do
      assert JiuquJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < 60 被拒（基本剑法火候不够）" do
      assert JiuquJian.valid_learn(stats(200, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候不够，无法学习九曲剑法。\n"}
    end

    test "sword < jiuqu-jian 被拒（基本剑法水平有限）" do
      assert JiuquJian.valid_learn(stats(200, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候有限，无法领会更高深的九曲剑法。\n"}
    end

    test "四项全满足则放行" do
      assert JiuquJian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert JiuquJian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JiuquJian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 40 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert JiuquJian.practice_cost() == %{qi: 40, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jiuqu-jian") == JiuquJian
    end
  end
end

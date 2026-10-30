defmodule Kantele.Combat.SkillsQiankunJianTest do
  @moduledoc """
  乾坤剑法学习门槛迁移（C 相位，qiankun-jian 真缺口补齐）。

  对照 `kungfu/skill/qiankun-jian.c`：
  - valid_learn: force>=180 / max_neili>=2000 / sword>=150 / sword>=qiankun-jian；
  - practice_skill 扣 qi 65 / neili 70（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QiankunJian

  defp stats(force, sword, qiankun),
    do: %{skills: %{"force" => force, "sword" => sword, "qiankun-jian" => qiankun}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=180 / max_neili>=2000 / sword>=150 / sword>=qiankun-jian）" do
    test "force < 180 被拒（内功火候不到）" do
      assert QiankunJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不到，无法学习乾坤神剑。\n"}
    end

    test "max_neili < 2000 被拒（内力太差）" do
      assert QiankunJian.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力太差，无法学习乾坤神剑。\n"}
    end

    test "sword < 150 被拒（基本剑法火候太浅）" do
      assert QiankunJian.valid_learn(stats(200, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，无法学习乾坤神剑。\n"}
    end

    test "sword < qiankun-jian 被拒（基本剑法水平有限）" do
      assert QiankunJian.valid_learn(stats(200, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的乾坤神剑。\n"}
    end

    test "四项全满足则放行" do
      assert QiankunJian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert QiankunJian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert QiankunJian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 65 / neili 70）" do
    test "返回 LPC 一致的消耗" do
      assert QiankunJian.practice_cost() == %{qi: 65, neili: 70}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qiankun-jian") == QiankunJian
    end
  end
end

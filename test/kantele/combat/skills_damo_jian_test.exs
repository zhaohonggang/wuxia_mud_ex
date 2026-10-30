defmodule Kantele.Combat.SkillsDamoJianTest do
  @moduledoc """
  达摩剑法学习门槛迁移（C 相位，damo-jian 真缺口补齐）。

  对照 `kungfu/skill/da mo-jian.c`：
  - valid_learn: max_neili>=300 / int>=30 / force>=60 / sword>=damo-jian；
  - practice_skill 扣 qi 62 / neili 69（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DamoJian

  defp stats(int, force, sword, damo),
    do: %{int: int, skills: %{"force" => force, "sword" => sword, "damo-jian" => damo}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=300 / int>=30 / force>=60 / sword>=damo-jian）" do
    test "max_neili < 300 被拒（内力不够）" do
      assert DamoJian.valid_learn(stats(50, 200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "int < 30 被拒（先天悟性不足）" do
      assert DamoJian.valid_learn(stats(10, 200, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的先天悟性不足。\n"}
    end

    test "force < 60 被拒（内功火候太浅）" do
      assert DamoJian.valid_learn(stats(50, 10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < damo-jian 被拒（基本剑法水平有限）" do
      assert DamoJian.valid_learn(stats(50, 200, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的达摩剑法。\n"}
    end

    test "四项全满足则放行" do
      assert DamoJian.valid_learn(stats(50, 200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert DamoJian.valid_learn(stats(50, 200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DamoJian.valid_learn(stats(50, 200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 62 / neili 69）" do
    test "返回 LPC 一致的消耗" do
      assert DamoJian.practice_cost() == %{qi: 62, neili: 69}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("damo-jian") == DamoJian
    end
  end
end

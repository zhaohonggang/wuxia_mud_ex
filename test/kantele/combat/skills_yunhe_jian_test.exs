defmodule Kantele.Combat.SkillsYunheJianTest do
  @moduledoc """
  云鹤剑法学习门槛迁移（C 相位，yunhe-jian 真缺口补齐）。

  对照 `kungfu/skill/yunhe-jian.c`：
  - valid_learn: max_neili>=100 / force>=20 / sword>=30 / sword>=yunhe-jian；
  - practice_skill 扣 qi 50 / neili 45（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.YunheJian

  defp stats(force, sword, yunhe),
    do: %{skills: %{"force" => force, "sword" => sword, "yunhe-jian" => yunhe}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / force>=20 / sword>=30 / sword>=yunhe-jian）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert YunheJian.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 20 被拒（内功火候太浅）" do
      assert YunheJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < 30 被拒（基本剑法火候太浅）" do
      assert YunheJian.valid_learn(stats(100, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，无法修炼云鹤七剑。\n"}
    end

    test "sword < yunhe-jian 被拒（基本剑法水平有限）" do
      assert YunheJian.valid_learn(stats(100, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的云鹤七剑。\n"}
    end

    test "四项全满足则放行" do
      assert YunheJian.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert YunheJian.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert YunheJian.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 45）" do
    test "返回 LPC 一致的消耗" do
      assert YunheJian.practice_cost() == %{qi: 50, neili: 45}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("yunhe-jian") == YunheJian
    end
  end
end

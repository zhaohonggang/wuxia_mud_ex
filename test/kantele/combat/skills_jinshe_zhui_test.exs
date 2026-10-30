defmodule Kantele.Combat.SkillsJinsheZhuiTest do
  @moduledoc """
  金蛇锥法学习门槛迁移（C 相位，jinshe-zhui 真缺口补齐）。

  对照 `kungfu/skill/jinshe-zhui.c`：
  - valid_learn: max_neili>=500 / force>=80 / throwing>=jinshe-zhui；
  - practice_skill 扣 qi 35 / neili 48（须持暗器，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JinsheZhui

  defp stats(force, throwing, jinshe),
    do: %{skills: %{"force" => force, "throwing" => throwing, "jinshe-zhui" => jinshe}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=500 / force>=80 / throwing>=self）" do
    test "max_neili < 500 被拒（内力不够）" do
      assert JinsheZhui.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够，没有办法练金蛇锥法。\n"}
    end

    test "force < 80 被拒（内功火候不够）" do
      assert JinsheZhui.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，没有办法练金蛇锥法。\n"}
    end

    test "throwing < jinshe-zhui 被拒（基本暗器水平有限）" do
      assert JinsheZhui.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本暗器水平有限，无法领会更高深的金蛇锥法。\n"}
    end

    test "三项全满足则放行" do
      assert JinsheZhui.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert JinsheZhui.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JinsheZhui.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / neili 48）" do
    test "返回 LPC 一致的消耗" do
      assert JinsheZhui.practice_cost() == %{qi: 35, neili: 48}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jinshe-zhui") == JinsheZhui
    end
  end
end

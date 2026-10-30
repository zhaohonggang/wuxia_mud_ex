defmodule Kantele.Combat.SkillsSanhuaZhangTest do
  @moduledoc """
  三花掌法学习门槛迁移（C 相位，sanhua-zhang 真缺口补齐）。

  对照 `kungfu/skill/sanhua-zhang.c`：
  - valid_learn: force>=60 / max_neili>=300 / strike>=sanhua-zhang（须空手由 practice 流程把关）；
  - practice_skill 扣 qi 65 / neili 66（须空手，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SanhuaZhang

  defp stats(force, strike, sanhua),
    do: %{skills: %{"force" => force, "strike" => strike, "sanhua-zhang" => sanhua}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=60 / max_neili>=300 / strike>=sanhua-zhang）" do
    test "force < 60 被拒（内功火候不够）" do
      assert SanhuaZhang.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学散花掌。\n"}
    end

    test "max_neili < 300 被拒（内力太弱）" do
      assert SanhuaZhang.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力太弱，无法练散花掌。\n"}
    end

    test "strike < sanhua-zhang 被拒（基本掌法火候有限）" do
      assert SanhuaZhang.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本掌法火候水平有限，无法领会更高深的散花掌。\n"}
    end

    test "三项全满足则放行" do
      assert SanhuaZhang.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert SanhuaZhang.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert SanhuaZhang.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 65 / neili 66）" do
    test "返回 LPC 一致的消耗" do
      assert SanhuaZhang.practice_cost() == %{qi: 65, neili: 66}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("sanhua-zhang") == SanhuaZhang
    end
  end
end

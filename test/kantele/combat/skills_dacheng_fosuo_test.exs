defmodule Kantele.Combat.SkillsDachengFosuoTest do
  @moduledoc """
  大乘佛索学习门槛迁移（C 相位，dacheng-fosuo 真缺口补齐）。

  对照 `kungfu/skill/dacheng-fosuo.c`：
  - valid_learn: max_neili>=1000 / shaolin-xinfa>=80；
  - practice_skill 扣 qi 90 / neili 90（须持鞭，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DachengFosuo

  defp stats(shaolin, dacheng),
    do: %{skills: %{"shaolin-xinfa" => shaolin, "dacheng-fosuo" => dacheng}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1000 / shaolin-xinfa>=80）" do
    test "max_neili < 1000 被拒（内力修为不足）" do
      assert DachengFosuo.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不足，没有办法练大乘佛索。\n"}
    end

    test "shaolin-xinfa < 80 被拒（少林心法火候太浅）" do
      assert DachengFosuo.valid_learn(stats(10, 50), char_with_max_neili(2000)) ==
               {:error, "你的少林心法火候太浅。\n"}
    end

    test "两项全满足则放行" do
      assert DachengFosuo.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert DachengFosuo.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DachengFosuo.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 90 / neili 90）" do
    test "返回 LPC 一致的消耗" do
      assert DachengFosuo.practice_cost() == %{qi: 90, neili: 90}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("dacheng-fosuo") == DachengFosuo
    end
  end
end

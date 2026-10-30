defmodule Kantele.Combat.SkillsJingyueBifaTest do
  @moduledoc """
  惊月笔法学习门槛迁移（C 相位，jingyue-bifa 真缺口补齐）。

  对照 `kungfu/skill/jingyue-bifa.c`：
  - valid_learn: max_neili>=100 / dagger>=jingyue-bifa（LPC 另查须持短兵，由 practice 流程把关）；
  - practice_skill 扣 qi 45 / neili 42。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JingyueBifa

  defp stats(dagger, self_lvl),
    do: %{skills: %{"dagger" => dagger, "jingyue-bifa" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / dagger>=self）" do
    test "max_neili < 100 被拒（内力修为不够）" do
      assert JingyueBifa.valid_learn(stats(200, 50), char_with_max_neili(50)) ==
               {:error, "你的内力修为不够。\n"}
    end

    test "dagger < jingyue-bifa 被拒（基本短兵水平有限）" do
      assert JingyueBifa.valid_learn(stats(200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本短兵水平有限，无法领会更高深的惊月笔法。\n"}
    end

    test "两项全满足则放行" do
      assert JingyueBifa.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert JingyueBifa.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JingyueBifa.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 42）" do
    test "返回 LPC 一致的消耗" do
      assert JingyueBifa.practice_cost() == %{qi: 45, neili: 42}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jingyue-bifa") == JingyueBifa
    end
  end
end

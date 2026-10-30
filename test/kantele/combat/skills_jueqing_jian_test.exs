defmodule Kantele.Combat.SkillsJueqingJianTest do
  @moduledoc """
  绝情剑法学习门槛迁移（C 相位，jueqing-jian 真缺口补齐）。

  对照 `kungfu/skill/jueqing-jian.c`：
  - valid_learn: max_neili>=100 / sword>=15 / sword>=jueqing-jian；
  - practice_skill 扣 qi 45 / neili 30（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JueqingJian

  defp stats(sword, jueqing),
    do: %{skills: %{"sword" => sword, "jueqing-jian" => jueqing}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / sword>=15 / sword>=jueqing-jian）" do
    test "max_neili < 100 被拒（内力修为不够）" do
      assert JueqingJian.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你目前的内力修为不够，没有办法练绝情剑法。\n"}
    end

    test "sword < 15 被拒（基本剑法火候太浅）" do
      assert JueqingJian.valid_learn(stats(5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，没有办法练绝情剑法。\n"}
    end

    test "sword < jueqing-jian 被拒（基本剑法水平有限）" do
      assert JueqingJian.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候有限，无法领会更高深的绝情剑法。\n"}
    end

    test "三项全满足则放行" do
      assert JueqingJian.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert JueqingJian.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JueqingJian.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 30）" do
    test "返回 LPC 一致的消耗" do
      assert JueqingJian.practice_cost() == %{qi: 45, neili: 30}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jueqing-jian") == JueqingJian
    end
  end
end

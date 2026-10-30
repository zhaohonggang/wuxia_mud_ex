defmodule Kantele.Combat.SkillsHouquanTest do
  @moduledoc """
  猴拳学习门槛迁移（C 相位，houquan 真缺口补齐）。

  对照 `kungfu/skill/houquan.c`：
  - valid_learn: force>=30 / max_neili>=200（须空手由 practice 流程把关）；
  - practice_skill 扣 qi 25 / neili 18（须空手，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.Houquan

  defp stats(force, houquan),
    do: %{skills: %{"force" => force, "houquan" => houquan}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=30 / max_neili>=200）" do
    test "force < 30 被拒（内功火候不够）" do
      assert Houquan.valid_learn(stats(10, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本内功火候不够，无法学猴拳。\n"}
    end

    test "max_neili < 200 被拒（内力太弱）" do
      assert Houquan.valid_learn(stats(100, 50), char_with_max_neili(20)) ==
               {:error, "你的内力太弱，无法练猴拳。\n"}
    end

    test "两项全满足则放行" do
      assert Houquan.valid_learn(stats(100, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert Houquan.valid_learn(stats(100, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert Houquan.valid_learn(stats(100, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 25 / neili 18）" do
    test "返回 LPC 一致的消耗" do
      assert Houquan.practice_cost() == %{qi: 25, neili: 18}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("houquan") == Houquan
    end
  end
end

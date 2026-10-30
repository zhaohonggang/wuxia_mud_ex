defmodule Kantele.Combat.SkillsBizhenQingzhangTest do
  @moduledoc """
  碧针清掌学习门槛迁移（C 相位，bizhen-qingzhang 真缺口补齐）。

  对照 `kungfu/skill/bizhen-qingzhang.c`：
  - valid_learn: force>=200 / max_neili>=1000 / strike>=140 / strike>=bizhen-qingzhang；
  - practice_skill 扣 qi 80 / neili 80（空手）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BizhenQingzhang

  defp stats(force, strike, bizhen),
    do: %{skills: %{"force" => force, "strike" => strike, "bizhen-qingzhang" => bizhen}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=200 / max_neili>=1000 / strike>=140 / strike>=self）" do
    test "force < 200 被拒（内功火候不够）" do
      assert BizhenQingzhang.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法练习碧针清掌。\n"}
    end

    test "max_neili < 1000 被拒（内力太弱）" do
      assert BizhenQingzhang.valid_learn(stats(300, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力太弱，无法练习碧针清掌。\n"}
    end

    test "strike < 140 被拒（基本掌法火候不够）" do
      assert BizhenQingzhang.valid_learn(stats(300, 100, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本掌法火候不够，无法练习碧针清掌。\n"}
    end

    test "strike < bizhen-qingzhang 被拒（基本掌法水平有限）" do
      assert BizhenQingzhang.valid_learn(stats(300, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本掌法水平有限，无法领会更高深的碧针清掌。\n"}
    end

    test "四项全满足则放行" do
      assert BizhenQingzhang.valid_learn(stats(300, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert BizhenQingzhang.valid_learn(stats(300, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert BizhenQingzhang.valid_learn(stats(300, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 80 / neili 80）" do
    test "返回 LPC 一致的消耗" do
      assert BizhenQingzhang.practice_cost() == %{qi: 80, neili: 80}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("bizhen-qingzhang") == BizhenQingzhang
    end
  end
end

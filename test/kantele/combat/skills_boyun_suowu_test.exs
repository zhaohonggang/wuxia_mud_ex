defmodule Kantele.Combat.SkillsBoyunSuowuTest do
  @moduledoc """
  拨云锁雾学习门槛迁移（C 相位，boyun-suowu 真缺口补齐）。

  对照 `kungfu/skill/boyun-suowu.c`：
  - valid_learn: biyun-xinfa>=10 / max_neili>=100；
  - practice_skill 扣 qi 25 / neili 100（空手）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BoyunSuowu

  defp stats(biyun), do: %{skills: %{"biyun-xinfa" => biyun}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC biyun-xinfa>=10 / max_neili>=100）" do
    test "biyun-xinfa < 10 被拒（碧云心法火候不够）" do
      assert BoyunSuowu.valid_learn(stats(5), char_with_max_neili(2000)) ==
               {:error, "你的碧云心法火候不够，无法学拨云锁雾。\n"}
    end

    test "max_neili < 100 被拒（内力太弱）" do
      assert BoyunSuowu.valid_learn(stats(20), char_with_max_neili(20)) ==
               {:error, "你的内力太弱，无法练拨云锁雾。\n"}
    end

    test "两项全满足则放行" do
      assert BoyunSuowu.valid_learn(stats(20), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert BoyunSuowu.valid_learn(stats(20), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert BoyunSuowu.valid_learn(stats(20), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 25 / neili 100）" do
    test "返回 LPC 一致的消耗" do
      assert BoyunSuowu.practice_cost() == %{qi: 25, neili: 100}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("boyun-suowu") == BoyunSuowu
    end
  end
end

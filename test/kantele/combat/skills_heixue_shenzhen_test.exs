defmodule Kantele.Combat.SkillsHeixueShenzhenTest do
  @moduledoc """
  黑血神针学习门槛迁移（C 相位，heixue-shenzhen 真缺口补齐）。

  对照 `kungfu/skill/heixue-shenzhen.c`：
  - valid_learn: max_neili>=500 / force>=80 / throwing>=heixue-shenzhen；
  - practice_skill 扣 qi 35 / neili 48。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HeixueShenzhen

  defp stats(force, throwing, self_lvl),
    do: %{skills: %{"force" => force, "throwing" => throwing, "heixue-shenzhen" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=500 / force>=80 / throwing>=self）" do
    test "max_neili < 500 被拒（内力不够）" do
      assert HeixueShenzhen.valid_learn(stats(200, 200, 50), char_with_max_neili(100)) ==
               {:error, "你的内力不够，没有办法练黑血神针。\n"}
    end

    test "force < 80 被拒（内功火候不够）" do
      assert HeixueShenzhen.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，没有办法练黑血神针。\n"}
    end

    test "throwing < heixue-shenzhen 被拒（基本暗器水平有限）" do
      assert HeixueShenzhen.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本暗器水平有限，无法领会更高深的黑血神针。\n"}
    end

    test "三项全满足则放行" do
      assert HeixueShenzhen.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert HeixueShenzhen.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert HeixueShenzhen.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / neili 48）" do
    test "返回 LPC 一致的消耗" do
      assert HeixueShenzhen.practice_cost() == %{qi: 35, neili: 48}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("heixue-shenzhen") == HeixueShenzhen
    end
  end
end

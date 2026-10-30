defmodule Kantele.Combat.SkillsQianyeShouTest do
  @moduledoc """
  如来千叶手学习门槛迁移（C 相位，qianye-shou 真缺口补齐）。

  对照 `kungfu/skill/qianye-shou.c`：
  - valid_learn: force>=40 / max_neili>=200 / hand>=qianye-shou（LPC 另查须空手，由 practice 流程把关）；
  - practice_skill 扣 qi 68 / neili 64。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QianyeShou

  defp stats(force, hand, self_lvl),
    do: %{skills: %{"force" => force, "hand" => hand, "qianye-shou" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=40 / max_neili>=200 / hand>=self）" do
    test "force < 40 被拒（内功火候不够）" do
      assert QianyeShou.valid_learn(stats(20, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学如来千叶手。\n"}
    end

    test "max_neili < 200 被拒（内力太弱）" do
      assert QianyeShou.valid_learn(stats(200, 200, 50), char_with_max_neili(100)) ==
               {:error, "你的内力太弱，无法练如来千叶手。\n"}
    end

    test "hand < qianye-shou 被拒（基本手法水平有限）" do
      assert QianyeShou.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本手法水平有限，无法领会更高深的如来千叶手。\n"}
    end

    test "三项全满足则放行" do
      assert QianyeShou.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert QianyeShou.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert QianyeShou.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 68 / neili 64）" do
    test "返回 LPC 一致的消耗" do
      assert QianyeShou.practice_cost() == %{qi: 68, neili: 64}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qianye-shou") == QianyeShou
    end
  end
end

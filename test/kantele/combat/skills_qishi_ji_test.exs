defmodule Kantele.Combat.SkillsQishiJiTest do
  @moduledoc """
  圣骑士戟学习门槛迁移（C 相位，qishi-ji 真缺口补齐）。

  对照 `kungfu/skill/qishi-ji.c`：
  - valid_learn: max_neili>=100 / force>=30 / club>=qishi-ji（LPC 重复行已合并，末门文案 verbatim「基本剑法」）；
  - practice_skill 扣 qi 70 / neili 40（须持戟，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QishiJi

  defp stats(force, club, self_lvl),
    do: %{skills: %{"force" => force, "club" => club, "qishi-ji" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / force>=30 / club>=self）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert QishiJi.valid_learn(stats(200, 200, 50), char_with_max_neili(50)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 30 被拒（内功火候不够）" do
      assert QishiJi.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够。\n"}
    end

    test "club < qishi-ji 被拒（基本剑法水平有限，LPC verbatim）" do
      assert QishiJi.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的圣骑士戟。\n"}
    end

    test "三项全满足则放行" do
      assert QishiJi.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert QishiJi.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 70 / neili 40）" do
    test "返回 LPC 一致的消耗" do
      assert QishiJi.practice_cost() == %{qi: 70, neili: 40}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qishi-ji") == QishiJi
    end
  end
end

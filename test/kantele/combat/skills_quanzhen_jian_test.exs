defmodule Kantele.Combat.SkillsQuanzhenJianTest do
  @moduledoc """
  全真剑法学习门槛迁移（C 相位，quanzhen-jian 真缺口补齐）。

  对照 `kungfu/skill/quanzhen-jian.c`：
  - valid_learn: force>=150 / max_neili>=1000 / sword>=100 / sword>=quanzhen-jian；
  - practice_skill 扣 qi 55 / neili 53（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QuanzhenJian

  defp stats(force, sword, quanzhen),
    do: %{skills: %{"force" => force, "sword" => sword, "quanzhen-jian" => quanzhen}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=150 / max_neili>=1000 / sword>=100 / sword>=quanzhen-jian）" do
    test "force < 150 被拒（内功火候不足）" do
      assert QuanzhenJian.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不足，无法学习全真剑法。\n"}
    end

    test "max_neili < 1000 被拒（内力修为太差）" do
      assert QuanzhenJian.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为太差，无法学习全真剑法。\n"}
    end

    test "sword < 100 被拒（基本剑法修为不够）" do
      assert QuanzhenJian.valid_learn(stats(200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法修为不够，无法学习全真剑法。\n"}
    end

    test "sword < quanzhen-jian 被拒（基本剑法水平有限）" do
      assert QuanzhenJian.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的全真剑法。\n"}
    end

    test "四项全满足则放行" do
      assert QuanzhenJian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert QuanzhenJian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert QuanzhenJian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 53）" do
    test "返回 LPC 一致的消耗" do
      assert QuanzhenJian.practice_cost() == %{qi: 55, neili: 53}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("quanzhen-jian") == QuanzhenJian
    end
  end
end

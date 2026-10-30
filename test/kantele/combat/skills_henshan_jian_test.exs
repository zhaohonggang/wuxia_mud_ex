defmodule Kantele.Combat.SkillsHenshanJianTest do
  @moduledoc """
  衡山剑法学习门槛迁移（C 相位，henshan-jian 真缺口补齐）。

  对照 `kungfu/skill/henshan-jian.c`：
  - valid_learn: max_neili>=80 / sword>=10 / sword>=henshan-jian；
  - practice_skill 扣 qi 45 / neili 30（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HenshanJian

  defp stats(sword, henshan),
    do: %{skills: %{"sword" => sword, "henshan-jian" => henshan}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=80 / sword>=10 / sword>=henshan-jian）" do
    test "max_neili < 80 被拒（内力修为不够）" do
      assert HenshanJian.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你目前的内力修为不够，没有办法练衡山剑法。\n"}
    end

    test "sword < 10 被拒（基本剑法火候太浅）" do
      assert HenshanJian.valid_learn(stats(5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，没有办法练衡山剑法。\n"}
    end

    test "sword < henshan-jian 被拒（基本剑法火候有限）" do
      assert HenshanJian.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候有限，无法领会更高深的衡山剑法。\n"}
    end

    test "三项全满足则放行" do
      assert HenshanJian.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert HenshanJian.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert HenshanJian.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 30）" do
    test "返回 LPC 一致的消耗" do
      assert HenshanJian.practice_cost() == %{qi: 45, neili: 30}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("henshan-jian") == HenshanJian
    end
  end
end

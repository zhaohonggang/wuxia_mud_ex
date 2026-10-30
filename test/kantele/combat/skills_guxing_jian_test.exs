defmodule Kantele.Combat.SkillsGuxingJianTest do
  @moduledoc """
  孤星剑法学习门槛迁移（C 相位，guxing-jian 真缺口补齐）。

  对照 `kungfu/skill/guxing-jian.c`：
  - valid_learn: max_neili>=400 / force>=100 / sword>=80 / sword>=guxing-jian；
  - practice_skill 扣 qi 45 / neili 35（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.GuxingJian

  defp stats(force, sword, guxing),
    do: %{skills: %{"force" => force, "sword" => sword, "guxing-jian" => guxing}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=400 / force>=100 / sword>=80 / sword>=guxing-jian）" do
    test "max_neili < 400 被拒（内力修为不够）" do
      assert GuxingJian.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你目前的内力修为不够，没有办法练孤星剑法。\n"}
    end

    test "force < 100 被拒（内功修为不够）" do
      assert GuxingJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功修为不够，没有办法练孤星剑法。\n"}
    end

    test "sword < 80 被拒（基本剑法火候太浅）" do
      assert GuxingJian.valid_learn(stats(200, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，没有办法练孤星剑法。\n"}
    end

    test "sword < guxing-jian 被拒（基本剑法火候有限）" do
      assert GuxingJian.valid_learn(stats(200, 80, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候有限，无法领会更高深的孤星剑法。\n"}
    end

    test "四项全满足则放行" do
      assert GuxingJian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert GuxingJian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert GuxingJian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 35）" do
    test "返回 LPC 一致的消耗" do
      assert GuxingJian.practice_cost() == %{qi: 45, neili: 35}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("guxing-jian") == GuxingJian
    end
  end
end

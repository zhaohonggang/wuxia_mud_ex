defmodule Kantele.Combat.SkillsWudangJianTest do
  @moduledoc """
  武当剑法学习门槛迁移（C 相位，wudang-jian 真缺口补齐）。

  对照 `kungfu/skill/wudang-jian.c`：
  - valid_learn: max_neili>=100 / force>=20 / sword>=wudang-jian；
  - practice_skill 扣 qi 25 / neili 10（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.WudangJian

  defp stats(force, sword, wudang),
    do: %{skills: %{"force" => force, "sword" => sword, "wudang-jian" => wudang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / force>=20 / sword>=wudang-jian）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert WudangJian.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 20 被拒（内功火候太浅）" do
      assert WudangJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < wudang-jian 被拒（基本剑法水平有限）" do
      assert WudangJian.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的武当剑法。\n"}
    end

    test "三项全满足则放行" do
      assert WudangJian.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert WudangJian.valid_learn(stats(10, 200, 50), nil) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert WudangJian.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 25 / neili 10）" do
    test "返回 LPC 一致的消耗" do
      assert WudangJian.practice_cost() == %{qi: 25, neili: 10}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("wudang-jian") == WudangJian
    end
  end
end

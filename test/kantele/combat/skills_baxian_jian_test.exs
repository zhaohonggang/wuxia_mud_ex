defmodule Kantele.Combat.SkillsBaxianJianTest do
  @moduledoc """
  八仙剑法学习门槛迁移（C 相位，baxian-jian 真缺口补齐）。

  对照 `kungfu/skill/baxian-jian.c`：
  - valid_learn: max_neili>=200 / force>=20 / sword>=10 / sword>=baxian-jian；
  - practice_skill 扣 qi 43 / neili 44（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BaxianJian

  defp stats(force, sword, baxian),
    do: %{skills: %{"force" => force, "sword" => sword, "baxian-jian" => baxian}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=200 / force>=20 / sword>=10 / sword>=baxian-jian）" do
    test "max_neili < 200 被拒（内力不够）" do
      assert BaxianJian.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 20 被拒（内功火候太浅）" do
      assert BaxianJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < 10 被拒（基本剑法火候不够）" do
      assert BaxianJian.valid_learn(stats(100, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候不够，无法学习八仙剑法。\n"}
    end

    test "sword < baxian-jian 被拒（基本剑法水平有限）" do
      assert BaxianJian.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的八仙剑法。\n"}
    end

    test "四项全满足则放行" do
      assert BaxianJian.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert BaxianJian.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert BaxianJian.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 43 / neili 44）" do
    test "返回 LPC 一致的消耗" do
      assert BaxianJian.practice_cost() == %{qi: 43, neili: 44}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("baxian-jian") == BaxianJian
    end
  end
end

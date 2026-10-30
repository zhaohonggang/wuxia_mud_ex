defmodule Kantele.Combat.SkillsMingwangJianTest do
  @moduledoc """
  明王剑法学习门槛迁移（C 相位，mingwang-jian 真缺口补齐）。

  对照 `kungfu/skill/mingwang-jian.c`：
  - valid_learn: max_neili>=400 / force>=70 / sword>=mingwang-jian；
  - practice_skill 扣 qi 50 / neili 58（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.MingwangJian

  defp stats(force, sword, mingwang),
    do: %{skills: %{"force" => force, "sword" => sword, "mingwang-jian" => mingwang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=400 / force>=70 / sword>=mingwang-jian）" do
    test "max_neili < 400 被拒（内力不够）" do
      assert MingwangJian.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 70 被拒（内功火候太浅）" do
      assert MingwangJian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < mingwang-jian 被拒（基本剑法水平有限）" do
      assert MingwangJian.valid_learn(stats(200, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的不动明王剑法。\n"}
    end

    test "三项全满足则放行" do
      assert MingwangJian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert MingwangJian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert MingwangJian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 58）" do
    test "返回 LPC 一致的消耗" do
      assert MingwangJian.practice_cost() == %{qi: 50, neili: 58}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("mingwang-jian") == MingwangJian
    end
  end
end

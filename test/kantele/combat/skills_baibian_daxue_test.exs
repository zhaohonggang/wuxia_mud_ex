defmodule Kantele.Combat.SkillsBaibianDaxueTest do
  @moduledoc """
  百变打穴法学习门槛迁移（C 相位，baibian-daxue 真缺口补齐）。

  对照 `kungfu/skill/baibian-daxue.c`：
  - valid_learn: max_neili>=150 / force>=40 / staff>=baibian-daxue；
  - practice_skill 扣 qi 32 / neili 15（须持杖，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BaibianDaxue

  defp stats(force, staff, baibian),
    do: %{skills: %{"force" => force, "staff" => staff, "baibian-daxue" => baibian}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=150 / force>=40 / staff>=baibian-daxue）" do
    test "max_neili < 150 被拒（内力不够）" do
      assert BaibianDaxue.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够，没有办法练百变打穴法。\n"}
    end

    test "force < 40 被拒（内功火候不够）" do
      assert BaibianDaxue.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，还不能学习百变打穴法!\n"}
    end

    test "staff < baibian-daxue 被拒（基本杖法水平有限）" do
      assert BaibianDaxue.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法水平有限，无法领会更高深的百变打穴杖法。\n"}
    end

    test "三项全满足则放行" do
      assert BaibianDaxue.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert BaibianDaxue.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert BaibianDaxue.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 32 / neili 15）" do
    test "返回 LPC 一致的消耗" do
      assert BaibianDaxue.practice_cost() == %{qi: 32, neili: 15}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("baibian-daxue") == BaibianDaxue
    end
  end
end

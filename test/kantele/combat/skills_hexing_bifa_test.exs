defmodule Kantele.Combat.SkillsHexingBifaTest do
  @moduledoc """
  鹤形笔法学习门槛迁移（C 相位，hexing-bifa 真缺口补齐）。

  对照 `kungfu/skill/hexing-bifa.c`：
  - valid_learn: max_neili>=300 / dagger>=hexing-bifa；
  - practice_skill 扣 qi 55 / neili 52（须持短兵，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HexingBifa

  defp stats(dagger, hexing),
    do: %{skills: %{"dagger" => dagger, "hexing-bifa" => hexing}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=300 / dagger>=self）" do
    test "max_neili < 300 被拒（内力修为不够）" do
      assert HexingBifa.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够。\n"}
    end

    test "dagger < hexing-bifa 被拒（基本短兵水平有限）" do
      assert HexingBifa.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本短兵水平有限，无法领会更高深的鹤形笔法。\n"}
    end

    test "两项全满足则放行" do
      assert HexingBifa.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert HexingBifa.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert HexingBifa.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 52）" do
    test "返回 LPC 一致的消耗" do
      assert HexingBifa.practice_cost() == %{qi: 55, neili: 52}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("hexing-bifa") == HexingBifa
    end
  end
end

defmodule Kantele.Combat.SkillsHanxingBadaTest do
  @moduledoc """
  寒星八打学习门槛迁移（C 相位，hanxing-bada 真缺口补齐）。

  对照 `kungfu/skill/hanxing-bada.c`：
  - valid_learn: max_neili>=200 / throwing>=hanxing-bada；
  - practice_skill 扣 qi 40 / neili 45（须持暗器，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HanxingBada

  defp stats(throwing, hanxing),
    do: %{skills: %{"throwing" => throwing, "hanxing-bada" => hanxing}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=200 / throwing>=self）" do
    test "max_neili < 200 被拒（内力不够）" do
      assert HanxingBada.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够，没有办法练寒星八打。\n"}
    end

    test "throwing < hanxing-bada 被拒（基本暗器水平有限）" do
      assert HanxingBada.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本暗器水平有限，无法领悟更高深的寒星八打术。\n"}
    end

    test "两项全满足则放行" do
      assert HanxingBada.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert HanxingBada.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert HanxingBada.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 40 / neili 45）" do
    test "返回 LPC 一致的消耗" do
      assert HanxingBada.practice_cost() == %{qi: 40, neili: 45}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("hanxing-bada") == HanxingBada
    end
  end
end

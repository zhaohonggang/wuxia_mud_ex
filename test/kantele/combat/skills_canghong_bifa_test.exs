defmodule Kantele.Combat.SkillsCanghongBifaTest do
  @moduledoc """
  沧虹笔法学习门槛迁移（C 相位，canghong-bifa 真缺口补齐）。

  对照 `kungfu/skill/canghong-bifa.c`：
  - valid_learn: max_neili>=500 / force>=100 / dagger>=30 / dagger>=canghong-bifa；
  - practice_skill 扣 qi 65 / neili 62（须持短兵，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.CanghongBifa

  defp stats(force, dagger, canghong),
    do: %{skills: %{"force" => force, "dagger" => dagger, "canghong-bifa" => canghong}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=500 / force>=100 / dagger>=30 / dagger>=self）" do
    test "max_neili < 500 被拒（内力不够）" do
      assert CanghongBifa.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 100 被拒（内功火候太浅）" do
      assert CanghongBifa.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "dagger < 30 被拒（基本短兵火候太浅）" do
      assert CanghongBifa.valid_learn(stats(200, 10, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本短兵火候太浅。\n"}
    end

    test "dagger < canghong-bifa 被拒（基本短兵水平有限）" do
      assert CanghongBifa.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本短兵水平有限，无法领会更高深的苍虹笔法。\n"}
    end

    test "四项全满足则放行" do
      assert CanghongBifa.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert CanghongBifa.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert CanghongBifa.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 65 / neili 62）" do
    test "返回 LPC 一致的消耗" do
      assert CanghongBifa.practice_cost() == %{qi: 65, neili: 62}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("canghong-bifa") == CanghongBifa
    end
  end
end

defmodule Kantele.Combat.SkillsDaliChuTest do
  @moduledoc """
  无上大力杵学习门槛迁移（C 相位，dali-chu 真缺口补齐）。

  对照 `kungfu/skill/dali-chu.c`：
  - valid_learn: max_neili>=300 / force>=30 / hammer>=20 / hammer>=dali-chu；
  - practice_skill 扣 qi 35 / neili 40（须持锤，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DaliChu

  defp stats(force, hammer, dali),
    do: %{skills: %{"force" => force, "hammer" => hammer, "dali-chu" => dali}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=300 / force>=30 / hammer>=20 / hammer>=dali-chu）" do
    test "max_neili < 300 被拒（内力修为不够）" do
      assert DaliChu.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够，难以修炼无上大力杵。\n"}
    end

    test "force < 30 被拒（内功火候太浅）" do
      assert DaliChu.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅，难以修炼无上大力杵。\n"}
    end

    test "hammer < 20 被拒（基本锤法不够）" do
      assert DaliChu.valid_learn(stats(100, 10, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本锤法不够，难以修炼无上大力杵。\n"}
    end

    test "hammer < dali-chu 被拒（基本锤法水平有限）" do
      assert DaliChu.valid_learn(stats(100, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本锤法水平有限，无法领会更高深的无上大力杵。\n"}
    end

    test "四项全满足则放行" do
      assert DaliChu.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert DaliChu.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DaliChu.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / neili 40）" do
    test "返回 LPC 一致的消耗" do
      assert DaliChu.practice_cost() == %{qi: 35, neili: 40}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("dali-chu") == DaliChu
    end
  end
end

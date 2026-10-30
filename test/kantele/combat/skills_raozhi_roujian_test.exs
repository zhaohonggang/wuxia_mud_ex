defmodule Kantele.Combat.SkillsRaozhiRoujianTest do
  @moduledoc """
  绕指柔剑学习门槛迁移（C 相位，raozhi-roujian 真缺口补齐）。

  对照 `kungfu/skill/raozhi-roujian.c`：
  - valid_learn: max_neili>=100 / force>=20 / sword>=raozhi-roujian；
  - practice_skill 扣 qi 35 / neili 30（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.RaozhiRoujian

  defp stats(force, sword, self_lvl),
    do: %{skills: %{"force" => force, "sword" => sword, "raozhi-roujian" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / force>=20 / sword>=self）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert RaozhiRoujian.valid_learn(stats(200, 200, 50), char_with_max_neili(50)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 20 被拒（内功火候太浅）" do
      assert RaozhiRoujian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < raozhi-roujian 被拒（基本剑法水平有限）" do
      assert RaozhiRoujian.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的绕指柔剑。\n"}
    end

    test "三项全满足则放行" do
      assert RaozhiRoujian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert RaozhiRoujian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert RaozhiRoujian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / neili 30）" do
    test "返回 LPC 一致的消耗" do
      assert RaozhiRoujian.practice_cost() == %{qi: 35, neili: 30}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("raozhi-roujian") == RaozhiRoujian
    end
  end
end

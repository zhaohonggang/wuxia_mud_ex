defmodule Kantele.Combat.SkillsShunvJianTest do
  @moduledoc """
  淑女剑法学习门槛迁移（C 相位，shunv-jian 真缺口补齐）。

  对照 `kungfu/skill/shunv-jian.c`：
  - valid_learn: max_neili>=100 / dodge>=40 / dex>=24 / sword>=shunv-jian；
  - practice_skill 扣 qi 40 / neili 34（须持剑，由 practice 流程把关；dex 走 query_dex 基础属性）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ShunvJian

  defp stats(dex, dodge, sword, shunv),
    do: %{dex: dex, skills: %{"dodge" => dodge, "sword" => sword, "shunv-jian" => shunv}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / dodge>=40 / dex>=24 / sword>=shunv-jian）" do
    test "max_neili < 100 被拒（内力修为不够）" do
      assert ShunvJian.valid_learn(stats(50, 200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够，无法修习淑女剑法。\n"}
    end

    test "dodge < 40 被拒（基本轻功火候太浅）" do
      assert ShunvJian.valid_learn(stats(50, 10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本轻功火候太浅，无法修习淑女剑法。\n"}
    end

    test "dex < 24 被拒（身法还不够灵活）" do
      assert ShunvJian.valid_learn(stats(10, 200, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的身法还不够灵活，无法修习淑女剑法。\n"}
    end

    test "sword < shunv-jian 被拒（基本剑法水平有限）" do
      assert ShunvJian.valid_learn(stats(50, 200, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的淑女剑法。\n"}
    end

    test "四项全满足则放行" do
      assert ShunvJian.valid_learn(stats(50, 200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert ShunvJian.valid_learn(stats(50, 200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert ShunvJian.valid_learn(stats(50, 200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 40 / neili 34）" do
    test "返回 LPC 一致的消耗" do
      assert ShunvJian.practice_cost() == %{qi: 40, neili: 34}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("shunv-jian") == ShunvJian
    end
  end
end

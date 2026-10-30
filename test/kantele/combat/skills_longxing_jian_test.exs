defmodule Kantele.Combat.SkillsLongxingJianTest do
  @moduledoc """
  龙形剑法学习门槛迁移（C 相位，longxing-jian 真缺口补齐）。

  对照 `kungfu/skill/longxing-jian.c`：
  - valid_learn: str>=24 / int>=30 / max_neili>=2000 / hunyuan-yiqi>=200 / sword>=200 / sword>=longxing-jian；
  - practice_skill 扣 qi 30 / neili 40（LPC 原文不查武器）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LongxingJian

  defp stats(str, int, hunyuan, sword, longxing),
    do: %{
      str: str,
      int: int,
      skills: %{"hunyuan-yiqi" => hunyuan, "sword" => sword, "longxing-jian" => longxing}
    }

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC str>=24 / int>=30 / max_neili>=2000 / hunyuan-yiqi>=200 / sword>=200 / sword>=longxing-jian）" do
    test "str < 24 被拒（先天臂力不足）" do
      assert LongxingJian.valid_learn(stats(10, 50, 300, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你先天臂力不足。\n"}
    end

    test "int < 30 被拒（先天悟性不足）" do
      assert LongxingJian.valid_learn(stats(50, 10, 300, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你先天悟性不足。\n"}
    end

    test "max_neili < 2000 被拒（内力修为不够）" do
      assert LongxingJian.valid_learn(stats(50, 50, 300, 300, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够，难以修炼龙形剑法。\n"}
    end

    test "hunyuan-yiqi < 200 被拒（内功火候太浅）" do
      assert LongxingJian.valid_learn(stats(50, 50, 10, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你的内功火候太浅，难以修炼龙形剑法。\n"}
    end

    test "sword < 200 被拒（剑法根基不足）" do
      assert LongxingJian.valid_learn(stats(50, 50, 300, 10, 50), char_with_max_neili(9999)) ==
               {:error, "你的剑法根基不足，难以修炼龙形剑法。\n"}
    end

    test "sword < longxing-jian 被拒（基本剑法水平有限）" do
      assert LongxingJian.valid_learn(stats(50, 50, 300, 300, 150), char_with_max_neili(9999)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的龙形剑法。\n"}
    end

    test "六项全满足则放行" do
      assert LongxingJian.valid_learn(stats(50, 50, 300, 300, 50), char_with_max_neili(9999)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert LongxingJian.valid_learn(stats(50, 50, 300, 300, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert LongxingJian.valid_learn(stats(50, 50, 300, 300, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 30 / neili 40）" do
    test "返回 LPC 一致的消耗" do
      assert LongxingJian.practice_cost() == %{qi: 30, neili: 40}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("longxing-jian") == LongxingJian
    end
  end
end

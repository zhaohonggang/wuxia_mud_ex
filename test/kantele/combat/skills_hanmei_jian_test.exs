defmodule Kantele.Combat.SkillsHanmeiJianTest do
  @moduledoc """
  寒梅剑法学习门槛迁移（C 相位，hanmei-jian 真缺口补齐）。

  对照 `kungfu/skill/hanmei-jian.c`：
  - valid_learn: max_neili>=200 / sword>=10 / sword>=hanmei-jian；
  - practice_skill 扣 qi 60 / neili 16（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HanmeiJian

  defp stats(sword, hanmei),
    do: %{skills: %{"sword" => sword, "hanmei-jian" => hanmei}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=200 / sword>=10 / sword>=hanmei-jian）" do
    test "max_neili < 200 被拒（内力不够）" do
      assert HanmeiJian.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够，无法修习寒梅剑法。\n"}
    end

    test "sword < 10 被拒（基本剑法火候太浅）" do
      assert HanmeiJian.valid_learn(stats(5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，无法修习寒梅剑法。\n"}
    end

    test "sword < hanmei-jian 被拒（基本剑法水平有限）" do
      assert HanmeiJian.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的寒梅剑法。\n"}
    end

    test "三项全满足则放行" do
      assert HanmeiJian.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert HanmeiJian.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert HanmeiJian.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 60 / neili 16）" do
    test "返回 LPC 一致的消耗" do
      assert HanmeiJian.practice_cost() == %{qi: 60, neili: 16}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("hanmei-jian") == HanmeiJian
    end
  end
end

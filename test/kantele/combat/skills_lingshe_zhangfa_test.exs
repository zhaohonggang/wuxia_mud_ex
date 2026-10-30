defmodule Kantele.Combat.SkillsLingsheZhangfaTest do
  @moduledoc """
  灵蛇杖法学习门槛迁移（C 相位，lingshe-zhangfa 真缺口补齐）。

  对照 `kungfu/skill/lingshe-zhangfa.c`：
  - valid_learn: max_neili>=1000 / force>=150 / staff>=100 / staff>=lingshe-zhangfa；
  - practice_skill 扣 qi 60 / neili 69（须持杖，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LingsheZhangfa

  defp stats(force, staff, self_lvl),
    do: %{skills: %{"force" => force, "staff" => staff, "lingshe-zhangfa" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1000 / force>=150 / staff>=100 / staff>=self）" do
    test "max_neili < 1000 被拒（内力不够）" do
      assert LingsheZhangfa.valid_learn(stats(200, 200, 50), char_with_max_neili(500)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 150 被拒（内功火候不够）" do
      assert LingsheZhangfa.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够。\n"}
    end

    test "staff < 100 被拒（基本杖法还不到家）" do
      assert LingsheZhangfa.valid_learn(stats(200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法还不到家，不能学习灵蛇杖法。\n"}
    end

    test "staff < lingshe-zhangfa 被拒（基本杖法水平不够）" do
      assert LingsheZhangfa.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法水平不够，无法领会更高深的灵蛇杖法。\n"}
    end

    test "四项全满足则放行" do
      assert LingsheZhangfa.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert LingsheZhangfa.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 60 / neili 69）" do
    test "返回 LPC 一致的消耗" do
      assert LingsheZhangfa.practice_cost() == %{qi: 60, neili: 69}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("lingshe-zhangfa") == LingsheZhangfa
    end
  end
end

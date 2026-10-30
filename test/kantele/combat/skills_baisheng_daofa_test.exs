defmodule Kantele.Combat.SkillsBaishengDaofaTest do
  @moduledoc """
  百胜刀法学习门槛迁移（C 相位，baisheng-daofa 真缺口补齐）。

  对照 `kungfu/skill/baisheng-daofa.c`：
  - valid_learn: max_neili>=600 / force>=100 / blade>=60 / blade>=baisheng-daofa；
  - practice_skill 扣 qi 45 / neili 68（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BaishengDaofa

  defp stats(force, blade, baisheng),
    do: %{skills: %{"force" => force, "blade" => blade, "baisheng-daofa" => baisheng}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=600 / force>=100 / blade>=60 / blade>=baisheng-daofa）" do
    test "max_neili < 600 被拒（内力不够）" do
      assert BaishengDaofa.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 100 被拒（内功火候太浅）" do
      assert BaishengDaofa.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "blade < 60 被拒（基本刀法火候不够）" do
      assert BaishengDaofa.valid_learn(stats(200, 30, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法火候不够，无法学习百胜刀法。\n"}
    end

    test "blade < baisheng-daofa 被拒（基本刀法水平有限）" do
      assert BaishengDaofa.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法领会更高深的百胜刀法。\n"}
    end

    test "四项全满足则放行" do
      assert BaishengDaofa.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert BaishengDaofa.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert BaishengDaofa.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 68）" do
    test "返回 LPC 一致的消耗" do
      assert BaishengDaofa.practice_cost() == %{qi: 45, neili: 68}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("baisheng-daofa") == BaishengDaofa
    end
  end
end

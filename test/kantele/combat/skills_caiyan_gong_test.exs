defmodule Kantele.Combat.SkillsCaiyanGongTest do
  @moduledoc """
  采燕功学习门槛迁移（C 相位，caiyan-gong 真缺口补齐）。

  对照 `kungfu/skill/caiyan-gong.c`：
  - valid_learn: max_neili>=250 / force>=50 / dodge>=caiyan-gong / club>=caiyan-gong；
  - practice_skill 扣 qi 62 / neili 61（须持棍，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.CaiyanGong

  defp stats(force, dodge, club, caiyan),
    do: %{skills: %{"force" => force, "dodge" => dodge, "club" => club, "caiyan-gong" => caiyan}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=250 / force>=50 / dodge>=self / club>=self）" do
    test "max_neili < 250 被拒（内力不够）" do
      assert CaiyanGong.valid_learn(stats(100, 200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 50 被拒（内功火候太浅）" do
      assert CaiyanGong.valid_learn(stats(10, 200, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "dodge < caiyan-gong 被拒（基本轻功水平有限）" do
      assert CaiyanGong.valid_learn(stats(100, 100, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本轻功水平有限，无法领会更高深的采燕功。\n"}
    end

    test "club < caiyan-gong 被拒（基本棍法水平有限）" do
      assert CaiyanGong.valid_learn(stats(100, 200, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本棍法水平有限，无法领会更高深的采燕功。\n"}
    end

    test "四项全满足则放行" do
      assert CaiyanGong.valid_learn(stats(100, 200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert CaiyanGong.valid_learn(stats(100, 200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert CaiyanGong.valid_learn(stats(100, 200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 62 / neili 61）" do
    test "返回 LPC 一致的消耗" do
      assert CaiyanGong.practice_cost() == %{qi: 62, neili: 61}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("caiyan-gong") == CaiyanGong
    end
  end
end

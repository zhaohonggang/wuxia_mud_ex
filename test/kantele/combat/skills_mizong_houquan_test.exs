defmodule Kantele.Combat.SkillsMizongHouquanTest do
  @moduledoc """
  迷踪猴拳学习门槛迁移（C 相位，mizong-houquan 真缺口补齐）。

  对照 `kungfu/skill/mizong-houquan.c`：
  - valid_learn: max_neili>=1200 / force>=100 / cuff>=100 / cuff>=mizong-houquan；
  - practice_skill 扣 qi 55 / neili 78（须空手，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.MizongHouquan

  defp stats(force, cuff, mizong),
    do: %{skills: %{"force" => force, "cuff" => cuff, "mizong-houquan" => mizong}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1200 / force>=100 / cuff>=100 / cuff>=mizong-houquan）" do
    test "max_neili < 1200 被拒（内力修为太弱）" do
      assert MizongHouquan.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为太弱，无法练迷踪猴拳。\n"}
    end

    test "force < 100 被拒（基本内功火候不够）" do
      assert MizongHouquan.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本内功火候不够，无法练迷踪猴拳。\n"}
    end

    test "cuff < 100 被拒（基本拳法火候不够）" do
      assert MizongHouquan.valid_learn(stats(200, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本拳法火候不够，无法练迷踪猴拳。\n"}
    end

    test "cuff < mizong-houquan 被拒（基本拳法水平有限）" do
      assert MizongHouquan.valid_learn(stats(200, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本拳法水平有限，无法领会更高深的迷踪猴拳。\n"}
    end

    test "四项全满足则放行" do
      assert MizongHouquan.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert MizongHouquan.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert MizongHouquan.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 78）" do
    test "返回 LPC 一致的消耗" do
      assert MizongHouquan.practice_cost() == %{qi: 55, neili: 78}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("mizong-houquan") == MizongHouquan
    end
  end
end

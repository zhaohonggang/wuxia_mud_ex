defmodule Kantele.Combat.SkillsJingangQuanTest do
  @moduledoc """
  金刚拳学习门槛迁移（C 相位，jingang-quan 真缺口补齐）。

  对照 `kungfu/skill/jingang-quan.c`：
  - valid_learn: force>=30 / max_neili>=100 / cuff>=jingang-quan；
  - practice_skill 扣 qi 59 / neili 58（须空手，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JingangQuan

  defp stats(force, cuff, jingang),
    do: %{skills: %{"force" => force, "cuff" => cuff, "jingang-quan" => jingang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=30 / max_neili>=100 / cuff>=jingang-quan）" do
    test "force < 30 被拒（内功火候不够）" do
      assert JingangQuan.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学大金刚拳。\n"}
    end

    test "max_neili < 100 被拒（内力太弱）" do
      assert JingangQuan.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力太弱，无法练大金刚拳。\n"}
    end

    test "cuff < jingang-quan 被拒（基本拳法水平有限）" do
      assert JingangQuan.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本拳法水平有限，无法领会更高深的大金刚拳。\n"}
    end

    test "三项全满足则放行" do
      assert JingangQuan.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert JingangQuan.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JingangQuan.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 59 / neili 58）" do
    test "返回 LPC 一致的消耗" do
      assert JingangQuan.practice_cost() == %{qi: 59, neili: 58}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jingang-quan") == JingangQuan
    end
  end
end

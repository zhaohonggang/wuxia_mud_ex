defmodule Kantele.Combat.SkillsLuoyingShenjianTest do
  @moduledoc """
  落英神剑学习门槛迁移（C 相位，luoying-shenjian 真缺口补齐）。

  对照 `kungfu/skill/luoying-shenjian.c`：
  - valid_learn: force>=30 / max_neili>=250 / sword>=luoying-shenjian；
  - practice_skill 扣 qi 45 / neili 41（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LuoyingShenjian

  defp stats(force, sword, luoying),
    do: %{skills: %{"force" => force, "sword" => sword, "luoying-shenjian" => luoying}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=30 / max_neili>=250 / sword>=luoying-shenjian）" do
    test "force < 30 被拒（内功火候不够）" do
      assert LuoyingShenjian.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，不能练落英神剑。\n"}
    end

    test "max_neili < 250 被拒（内力修为不够）" do
      assert LuoyingShenjian.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够，不能练落英神剑。\n"}
    end

    test "sword < luoying-shenjian 被拒（基本剑法水平有限）" do
      assert LuoyingShenjian.valid_learn(stats(200, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的落英神剑。\n"}
    end

    test "三项全满足则放行" do
      assert LuoyingShenjian.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert LuoyingShenjian.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert LuoyingShenjian.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 41）" do
    test "返回 LPC 一致的消耗" do
      assert LuoyingShenjian.practice_cost() == %{qi: 45, neili: 41}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("luoying-shenjian") == LuoyingShenjian
    end
  end
end

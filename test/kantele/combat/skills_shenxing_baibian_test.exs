defmodule Kantele.Combat.SkillsShenxingBaibianTest do
  @moduledoc """
  神行百变练招消耗迁移（C 相位，shenxing-baibian 真缺口补齐）。

  对照 `kungfu/skill/shenxing-baibian.c`：
  - valid_learn 为 `return 1`（无门槛），本版同样放行；
  - practice_skill: qi<50 / neili<30 则拒（由 practice 流程的体力检查把关），扣 qi 40；
    内力侧写作 `me->add("neill", -14)`（**拼写错误 `neill`**，该键不存在、内力实际不减），
    故 `practice_cost` 的 neili 记 0 —— 原样 bug 保真。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ShenxingBaibian

  describe "valid_learn/2（LPC return 1，无门槛）" do
    test "任意角色均放行" do
      assert ShenxingBaibian.valid_learn(%{skills: %{}}, nil) == :ok
      assert ShenxingBaibian.valid_learn(%{skills: %{}}, %{}) == :ok
    end
  end

  describe "practice_cost（LPC 扣 qi 40；内力侧 `neill` 拼写 bug 使实际不减，记 0）" do
    test "返回 LPC 一致的消耗" do
      assert ShenxingBaibian.practice_cost() == %{qi: 40, neili: 0}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("shenxing-baibian") == ShenxingBaibian
    end
  end
end

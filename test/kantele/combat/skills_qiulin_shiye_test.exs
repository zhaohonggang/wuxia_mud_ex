defmodule Kantele.Combat.SkillsQiulinShiyeTest do
  @moduledoc """
  秋林拾叶练招消耗迁移（C 相位，qiulin-shiye 真缺口补齐）。

  对照 `kungfu/skill/qiulin-shiye.c`：
  - valid_learn 为 `return 1`（无门槛），本版同样放行；
  - practice_skill: qi<40 则拒（由 practice 流程的体力检查把关），扣 qi 30、不耗 neili。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QiulinShiye

  describe "valid_learn/2（LPC return 1，无门槛）" do
    test "任意角色均放行" do
      assert QiulinShiye.valid_learn(%{skills: %{}}, nil) == :ok
      assert QiulinShiye.valid_learn(%{skills: %{}}, %{}) == :ok
    end
  end

  describe "practice_cost（LPC 扣 qi 30，不耗 neili）" do
    test "返回 LPC 一致的消耗" do
      assert QiulinShiye.practice_cost() == %{qi: 30, neili: 0}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qiulin-shiye") == QiulinShiye
    end
  end
end

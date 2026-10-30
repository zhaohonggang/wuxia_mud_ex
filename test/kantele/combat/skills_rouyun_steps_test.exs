defmodule Kantele.Combat.SkillsRouyunStepsTest do
  @moduledoc """
  柔云步学习门槛迁移（C 相位，rouyun-steps 真缺口补齐）。

  对照 `kungfu/skill/rouyun-steps.c`：
  - valid_learn: dex>30（LPC `query_dex() <= 30` 拒绝，文案无换行）；
  - practice_skill 扣 qi 45 / neili 20。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.RouyunSteps

  defp stats(dex), do: %{skills: %{}, dex: dex}

  describe "valid_learn/2 学习门槛（LPC dex>30，即 query_dex()<=30 拒）" do
    test "dex == 30 被拒（身法不够，LPC 文案无换行）" do
      assert RouyunSteps.valid_learn(stats(30), nil) ==
               {:error, "你的身法不够，难以领会柔云步法。"}
    end

    test "dex < 30 被拒" do
      assert RouyunSteps.valid_learn(stats(20), nil) ==
               {:error, "你的身法不够，难以领会柔云步法。"}
    end

    test "dex > 30 放行" do
      assert RouyunSteps.valid_learn(stats(31), nil) == :ok
    end

    test "character 任意值不影响（无 max_neili 门槛）" do
      assert RouyunSteps.valid_learn(stats(50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 20）" do
    test "返回 LPC 一致的消耗" do
      assert RouyunSteps.practice_cost() == %{qi: 45, neili: 20}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("rouyun-steps") == RouyunSteps
    end
  end
end

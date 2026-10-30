defmodule Kantele.Combat.SkillsSouguTest do
  @moduledoc """
  搜骨鹰爪功学习门槛迁移（C 相位，sougu 真缺口补齐）。

  对照 `kungfu/skill/sougu.c`：
  - valid_learn: force>=100 / max_neili>=600 / str>=33（LPC 另查须空手，由 practice 流程把关）；
  - practice_skill 扣 qi 55 / neili 57。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.Sougu

  defp stats(force, str), do: %{skills: %{"force" => force}, str: str}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=100 / max_neili>=600 / str>=33）" do
    test "force < 100 被拒（内功火候不够）" do
      assert Sougu.valid_learn(stats(50, 40), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学搜骨鹰爪功。\n"}
    end

    test "max_neili < 600 被拒（内力太弱）" do
      assert Sougu.valid_learn(stats(200, 40), char_with_max_neili(300)) ==
               {:error, "你的内力太弱，无法学搜骨鹰爪功。\n"}
    end

    test "str < 33 被拒（膂力太差）" do
      assert Sougu.valid_learn(stats(200, 20), char_with_max_neili(2000)) ==
               {:error, "你现在的膂力太差，还无法学搜骨鹰爪功。\n"}
    end

    test "三项全满足则放行" do
      assert Sougu.valid_learn(stats(200, 40), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert Sougu.valid_learn(stats(200, 40), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 57）" do
    test "返回 LPC 一致的消耗" do
      assert Sougu.practice_cost() == %{qi: 55, neili: 57}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("sougu") == Sougu
    end
  end
end

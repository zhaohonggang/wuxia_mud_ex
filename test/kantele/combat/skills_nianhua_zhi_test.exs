defmodule Kantele.Combat.SkillsNianhuaZhiTest do
  @moduledoc """
  拈花指学习门槛迁移（C 相位，nianhua-zhi 真缺口补齐）。

  对照 `kungfu/skill/nianhua-zhi.c`：
  - valid_learn: force>=60 / max_neili>=300 / finger>=nianhua-zhi（LPC 另查须空手，由 practice 流程把关）；
  - practice_skill 扣 qi 50 / neili 64。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.NianhuaZhi

  defp stats(force, finger, self_lvl),
    do: %{skills: %{"force" => force, "finger" => finger, "nianhua-zhi" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=60 / max_neili>=300 / finger>=self）" do
    test "force < 60 被拒（内功火候不够）" do
      assert NianhuaZhi.valid_learn(stats(30, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学拈花指。\n"}
    end

    test "max_neili < 300 被拒（内力太弱）" do
      assert NianhuaZhi.valid_learn(stats(200, 200, 50), char_with_max_neili(100)) ==
               {:error, "你的内力太弱，无法练拈花指。\n"}
    end

    test "finger < nianhua-zhi 被拒（基本指法水平有限）" do
      assert NianhuaZhi.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本指法水平有限，无法领会更高深的拈花指。\n"}
    end

    test "三项全满足则放行" do
      assert NianhuaZhi.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert NianhuaZhi.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert NianhuaZhi.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 64）" do
    test "返回 LPC 一致的消耗" do
      assert NianhuaZhi.practice_cost() == %{qi: 50, neili: 64}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("nianhua-zhi") == NianhuaZhi
    end
  end
end

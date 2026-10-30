defmodule Kantele.Combat.SkillsNingxueZhangTest do
  @moduledoc """
  凝雪杖法学习门槛迁移（C 相位，ningxue-zhang 真缺口补齐）。

  对照 `kungfu/skill/ningxue-zhang.c`：
  - valid_learn: max_neili>=200 / force>=60 / staff>=20 / staff>=ningxue-zhang（LPC 另查须持杖，由 practice 流程把关）；
  - practice_skill 扣 qi 75 / neili 78。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.NingxueZhang

  defp stats(force, staff, self_lvl),
    do: %{skills: %{"force" => force, "staff" => staff, "ningxue-zhang" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=200 / force>=60 / staff>=20 / staff>=self）" do
    test "max_neili < 200 被拒（内力修为不足）" do
      assert NingxueZhang.valid_learn(stats(200, 200, 50), char_with_max_neili(100)) ==
               {:error, "你的内力修为不足，无法学习凝雪杖法。\n"}
    end

    test "force < 60 被拒（内功火候太浅）" do
      assert NingxueZhang.valid_learn(stats(30, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅，无法学习凝雪杖法。\n"}
    end

    test "staff < 20 被拒（基本杖法太浅）" do
      assert NingxueZhang.valid_learn(stats(200, 10, 5), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法太浅，无法学习凝雪杖法。\n"}
    end

    test "staff < ningxue-zhang 被拒（基本杖法水平有限）" do
      assert NingxueZhang.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本杖法水平有限，无法领会更高深的凝雪杖法。\n"}
    end

    test "四项全满足则放行" do
      assert NingxueZhang.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert NingxueZhang.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 75 / neili 78）" do
    test "返回 LPC 一致的消耗" do
      assert NingxueZhang.practice_cost() == %{qi: 75, neili: 78}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("ningxue-zhang") == NingxueZhang
    end
  end
end

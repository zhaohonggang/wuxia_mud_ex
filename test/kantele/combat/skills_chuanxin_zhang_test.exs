defmodule Kantele.Combat.SkillsChuanxinZhangTest do
  @moduledoc """
  穿心掌学习门槛迁移（C 相位，chuanxin-zhang 真缺口补齐）。

  对照 `kungfu/skill/chuanxin-zhang.c`：
  - valid_learn: max_neili>=200 / strike>=30 / strike>=chuanxin-zhang；
  - practice_skill 扣 qi 45 / neili 48（空手）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ChuanxinZhang

  defp stats(strike, chuanxin),
    do: %{skills: %{"strike" => strike, "chuanxin-zhang" => chuanxin}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=200 / strike>=30 / strike>=self）" do
    test "max_neili < 200 被拒（内力修为太浅）" do
      assert ChuanxinZhang.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为太浅，无法练习穿心掌。\n"}
    end

    test "strike < 30 被拒（基本掌法太差）" do
      assert ChuanxinZhang.valid_learn(stats(100, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本掌法太差，无法领会穿心掌。\n"}
    end

    test "strike < chuanxin-zhang 被拒（基本掌法火候不够）" do
      assert ChuanxinZhang.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本掌法火候不够，无法领会更高深的穿心掌。\n"}
    end

    test "三项全满足则放行" do
      assert ChuanxinZhang.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert ChuanxinZhang.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert ChuanxinZhang.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 48）" do
    test "返回 LPC 一致的消耗" do
      assert ChuanxinZhang.practice_cost() == %{qi: 45, neili: 48}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("chuanxin-zhang") == ChuanxinZhang
    end
  end
end

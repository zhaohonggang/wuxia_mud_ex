defmodule Kantele.Combat.SkillsPangenCuojiefuTest do
  @moduledoc """
  盘根错节斧学习门槛迁移（C 相位，pangen-cuojiefu 真缺口补齐）。

  对照 `kungfu/skill/pangen-cuojiefu.c`：
  - valid_learn: force>=50 / max_neili>=600 / hammer>=30 / hammer>=pangen-cuojiefu；
  - practice_skill 扣 qi 80 / neili 52（须持锤，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.PangenCuojiefu

  defp stats(force, hammer, self_lvl),
    do: %{skills: %{"force" => force, "hammer" => hammer, "pangen-cuojiefu" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=50 / max_neili>=600 / hammer>=30 / hammer>=self）" do
    test "force < 50 被拒（内功火候不够）" do
      assert PangenCuojiefu.valid_learn(stats(30, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学盘根错节斧。\n"}
    end

    test "max_neili < 600 被拒（内力修为太弱）" do
      assert PangenCuojiefu.valid_learn(stats(200, 200, 50), char_with_max_neili(300)) ==
               {:error, "你的内力修为太弱，无法练盘根错节斧。\n"}
    end

    test "hammer < 30 被拒（基本锤法等级太低）" do
      assert PangenCuojiefu.valid_learn(stats(200, 20, 10), char_with_max_neili(2000)) ==
               {:error, "你的基本锤法等级太低，无法学盘根错节斧。\n"}
    end

    test "hammer < pangen-cuojiefu 被拒（基本锤法水平有限）" do
      assert PangenCuojiefu.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本锤法水平有限，无法领会更高深的盘根错节斧。\n"}
    end

    test "四项全满足则放行" do
      assert PangenCuojiefu.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert PangenCuojiefu.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 80 / neili 52）" do
    test "返回 LPC 一致的消耗" do
      assert PangenCuojiefu.practice_cost() == %{qi: 80, neili: 52}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("pangen-cuojiefu") == PangenCuojiefu
    end
  end
end

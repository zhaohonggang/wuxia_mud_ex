defmodule Kantele.Combat.SkillsPanlongSuoTest do
  @moduledoc """
  霹雳盘龙索学习门槛迁移（C 相位，panlong-suo 真缺口补齐）。

  对照 `kungfu/skill/panlong-suo.c`：
  - valid_learn: max_neili>=800 / force>=120 / whip>=80 / whip>=panlong-suo（LPC 另查须持鞭，由 practice 流程把关）；
  - practice_skill 扣 qi 75 / neili 85。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.PanlongSuo

  defp stats(force, whip, self_lvl),
    do: %{skills: %{"force" => force, "whip" => whip, "panlong-suo" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=800 / force>=120 / whip>=80 / whip>=self）" do
    test "max_neili < 800 被拒（内力修为不足）" do
      assert PanlongSuo.valid_learn(stats(200, 200, 50), char_with_max_neili(400)) ==
               {:error, "你的内力修为不足，无法修炼霹雳盘龙索。\n"}
    end

    test "force < 120 被拒（内功火候太浅）" do
      assert PanlongSuo.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅，无法修炼霹雳盘龙索。\n"}
    end

    test "whip < 80 被拒（基本鞭法火候太浅）" do
      assert PanlongSuo.valid_learn(stats(200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法火候太浅，无法修炼霹雳盘龙索。\n"}
    end

    test "whip < panlong-suo 被拒（基本鞭法水平还不够）" do
      assert PanlongSuo.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法水平还不够，无法领会更高深的霹雳盘龙索。\n"}
    end

    test "四项全满足则放行" do
      assert PanlongSuo.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert PanlongSuo.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 75 / neili 85）" do
    test "返回 LPC 一致的消耗" do
      assert PanlongSuo.practice_cost() == %{qi: 75, neili: 85}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("panlong-suo") == PanlongSuo
    end
  end
end

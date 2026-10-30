defmodule Kantele.Combat.SkillsChanhunSuoTest do
  @moduledoc """
  缠魂索学习门槛迁移（C 相位，chanhun-suo 真缺口补齐）。

  对照 `kungfu/skill/chanhun-suo.c`：
  - valid_learn: max_neili>=400 / force>=80 / whip>=60 / whip>=chanhun-suo；
  - practice_skill 扣 qi 50 / neili 50（须持鞭，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ChanhunSuo

  defp stats(force, whip, chanhun),
    do: %{skills: %{"force" => force, "whip" => whip, "chanhun-suo" => chanhun}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=400 / force>=80 / whip>=60 / whip>=self）" do
    test "max_neili < 400 被拒（内力不足）" do
      assert ChanhunSuo.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不足，没有办法练习缠魂索。\n"}
    end

    test "force < 80 被拒（内功火候太浅）" do
      assert ChanhunSuo.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "whip < 60 被拒（基本鞭法火候太浅）" do
      assert ChanhunSuo.valid_learn(stats(100, 30, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法火候太浅。\n"}
    end

    test "whip < chanhun-suo 被拒（基本鞭法水平有限）" do
      assert ChanhunSuo.valid_learn(stats(100, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法水平有限，无法领会更高深的缠魂索。\n"}
    end

    test "四项全满足则放行" do
      assert ChanhunSuo.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert ChanhunSuo.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert ChanhunSuo.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert ChanhunSuo.practice_cost() == %{qi: 50, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("chanhun-suo") == ChanhunSuo
    end
  end
end

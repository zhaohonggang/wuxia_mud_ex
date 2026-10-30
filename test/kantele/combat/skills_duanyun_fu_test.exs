defmodule Kantele.Combat.SkillsDuanyunFuTest do
  @moduledoc """
  断云斧学习门槛迁移（C 相位，duanyun-fu 真缺口补齐）。

  对照 `kungfu/skill/duanyun-fu.c`：
  - valid_enable: `axe` / `parry`（旧版本误作 `club`，已修正）；
  - valid_learn: force>=20 / max_neili>=150；
  - practice_skill 扣 qi 80；`receive_damage("neili", -12)` 为负伤害（实为回 12 内力，
    LPC 原样 bug），`practice_cost` 只能表达非负消耗，故 neili 记 0。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DuanyunFu

  defp stats(force), do: %{skills: %{"force" => force}}

  defp char(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_enable（LPC axe / parry）" do
    test "axe 与 parry 可用" do
      assert DuanyunFu.valid_enable("axe")
      assert DuanyunFu.valid_enable("parry")
    end

    test "club 不再可用（旧版本误作 club）" do
      refute DuanyunFu.valid_enable("club")
    end
  end

  describe "valid_learn/2 学习门槛（LPC force>=20 / max_neili>=150）" do
    test "force < 20 被拒（内功心法火候不够）" do
      assert DuanyunFu.valid_learn(stats(19), char(1000)) ==
               {:error, "你的内功心法火候不够，无法学断云斧。\n"}
    end

    test "max_neili < 150 被拒（内力太弱）" do
      assert DuanyunFu.valid_learn(stats(50), char(149)) ==
               {:error, "你的内力太弱，无法练断云斧。\n"}
    end

    test "两项满足则放行" do
      assert DuanyunFu.valid_learn(stats(20), char(150)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert DuanyunFu.valid_learn(stats(50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DuanyunFu.valid_learn(stats(50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC 扣 qi 80；neili 侧为回内，记 0）" do
    test "返回 LPC 一致的消耗" do
      assert DuanyunFu.practice_cost() == %{qi: 80, neili: 0}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("duanyun-fu") == DuanyunFu
    end
  end
end

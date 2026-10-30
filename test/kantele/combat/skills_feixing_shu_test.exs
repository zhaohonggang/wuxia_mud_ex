defmodule Kantele.Combat.SkillsFeixingShuTest do
  @moduledoc """
  飞星术学习门槛迁移（C 相位，feixing-shu 真缺口补齐）。

  对照 `kungfu/skill/feixing-shu.c`：
  - valid_learn: force>=50 / dodge>=40 / poison>=30 / dex>=25 / poison>=feixing-shu / throwing>=feixing-shu；
  - practice_skill 扣 qi 50 / neili 48。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.FeixingShu

  defp stats(force, dodge, poison, dex, throwing, self_lvl),
    do: %{
      skills: %{
        "force" => force,
        "dodge" => dodge,
        "poison" => poison,
        "throwing" => throwing,
        "feixing-shu" => self_lvl
      },
      dex: dex
    }

  describe "valid_learn/2 学习门槛（LPC force>=50 / dodge>=40 / poison>=30 / dex>=25 / poison>=self / throwing>=self）" do
    test "force < 50 被拒（内功心法火候不够）" do
      assert FeixingShu.valid_learn(stats(30, 200, 200, 40, 200, 0), nil) ==
               {:error, "你的内功心法火候不够，无法学飞星术。\n"}
    end

    test "dodge < 40 被拒（轻功火候不够）" do
      assert FeixingShu.valid_learn(stats(200, 30, 200, 40, 200, 0), nil) ==
               {:error, "你的轻功火候不够，无法学习飞星术。\n"}
    end

    test "poison < 30 被拒（毒功火候不够）" do
      assert FeixingShu.valid_learn(stats(200, 200, 20, 40, 200, 0), nil) ==
               {:error, "你的毒功火候不够，无法领悟飞星术。\n"}
    end

    test "dex < 25 被拒（身法不够灵巧）" do
      assert FeixingShu.valid_learn(stats(200, 200, 200, 20, 200, 0), nil) ==
               {:error, "你的身法不够灵巧，无法学习飞星术。\n"}
    end

    test "poison < feixing-shu 被拒（毒功水平有限）" do
      assert FeixingShu.valid_learn(stats(200, 200, 200, 40, 200, 250), nil) ==
               {:error, "你的毒功水平有限，无法领悟更高深的飞星术。\n"}
    end

    test "throwing < feixing-shu 被拒（基本暗器水平有限）" do
      assert FeixingShu.valid_learn(stats(200, 200, 300, 40, 200, 250), nil) ==
               {:error, "你的基本暗器水平有限，无法领悟更高深的飞星术。\n"}
    end

    test "六项全满足则放行" do
      assert FeixingShu.valid_learn(stats(200, 200, 200, 40, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 48）" do
    test "返回 LPC 一致的消耗" do
      assert FeixingShu.practice_cost() == %{qi: 50, neili: 48}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("feixing-shu") == FeixingShu
    end
  end
end

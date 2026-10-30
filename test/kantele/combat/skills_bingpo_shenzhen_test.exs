defmodule Kantele.Combat.SkillsBingpoShenzhenTest do
  @moduledoc """
  冰魄神针学习门槛迁移（C 相位，bingpo-shenzhen 真缺口补齐）。

  对照 `kungfu/skill/bingpo-shenzhen.c`：
  - valid_learn: force>=80 / dodge>=100 / dex>=34 / throwing>=bingpo-shenzhen；
  - practice_skill 扣 qi 72 / neili 65。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BingpoShenzhen

  defp stats(force, dodge, dex, throwing, self_lvl),
    do: %{
      skills: %{
        "force" => force,
        "dodge" => dodge,
        "throwing" => throwing,
        "bingpo-shenzhen" => self_lvl
      },
      dex: dex
    }

  describe "valid_learn/2 学习门槛（LPC force>=80 / dodge>=100 / dex>=34 / throwing>=self）" do
    test "force < 80 被拒（内功心法火候不够）" do
      assert BingpoShenzhen.valid_learn(stats(50, 200, 50, 200, 0), nil) ==
               {:error, "你的内功心法火候不够，无法学冰魄神针。\n"}
    end

    test "dodge < 100 被拒（轻功火候不够）" do
      assert BingpoShenzhen.valid_learn(stats(200, 50, 50, 200, 0), nil) ==
               {:error, "你的轻功火候不够，无法领悟冰魄神针。\n"}
    end

    test "dex < 34 被拒（身法不够灵巧）" do
      assert BingpoShenzhen.valid_learn(stats(200, 200, 20, 200, 0), nil) ==
               {:error, "你的身法不够灵巧，无法领悟冰魄神针。\n"}
    end

    test "throwing < bingpo-shenzhen 被拒（基本暗器水平有限）" do
      assert BingpoShenzhen.valid_learn(stats(200, 200, 50, 200, 250), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更高深的冰魄神针。\n"}
    end

    test "四项全满足则放行" do
      assert BingpoShenzhen.valid_learn(stats(200, 200, 50, 200, 100), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 72 / neili 65）" do
    test "返回 LPC 一致的消耗" do
      assert BingpoShenzhen.practice_cost() == %{qi: 72, neili: 65}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("bingpo-shenzhen") == BingpoShenzhen
    end
  end
end

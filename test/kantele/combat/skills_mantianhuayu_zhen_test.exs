defmodule Kantele.Combat.SkillsMantianhuayuZhenTest do
  @moduledoc """
  满天花雨掷金针学习门槛迁移（C 相位，mantianhuayu-zhen 真缺口补齐）。

  对照 `kungfu/skill/mantianhuayu-zhen.c`：
  - valid_learn: force>=60 / dodge>=60 / dex>=25 / throwing>=mantianhuayu-zhen；
  - practice_skill 扣 qi 45 / neili 45。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.MantianhuayuZhen

  defp stats(force, dodge, dex, throwing, self_lvl),
    do: %{
      skills: %{
        "force" => force,
        "dodge" => dodge,
        "throwing" => throwing,
        "mantianhuayu-zhen" => self_lvl
      },
      dex: dex
    }

  describe "valid_learn/2 学习门槛（LPC force>=60 / dodge>=60 / dex>=25 / throwing>=self）" do
    test "force < 60 被拒（内功心法火候不够）" do
      assert MantianhuayuZhen.valid_learn(stats(30, 200, 50, 200, 0), nil) ==
               {:error, "你的内功心法火候不够，无法学满天花雨掷金针。\n"}
    end

    test "dodge < 60 被拒（轻功火候不够）" do
      assert MantianhuayuZhen.valid_learn(stats(200, 30, 50, 200, 0), nil) ==
               {:error, "你的轻功火候不够，无法领悟满天花雨掷金针。\n"}
    end

    test "dex < 25 被拒（身法不够灵巧）" do
      assert MantianhuayuZhen.valid_learn(stats(200, 200, 20, 200, 0), nil) ==
               {:error, "你的身法不够灵巧，无法领悟满天花雨掷金针。\n"}
    end

    test "throwing < mantianhuayu-zhen 被拒（基本暗器水平有限）" do
      assert MantianhuayuZhen.valid_learn(stats(200, 200, 50, 200, 250), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更高深的满天花雨掷金针。\n"}
    end

    test "四项全满足则放行" do
      assert MantianhuayuZhen.valid_learn(stats(200, 200, 50, 200, 100), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 45）" do
    test "返回 LPC 一致的消耗" do
      assert MantianhuayuZhen.practice_cost() == %{qi: 45, neili: 45}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("mantianhuayu-zhen") == MantianhuayuZhen
    end
  end
end

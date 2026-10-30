defmodule Kantele.Combat.SkillsTangmenThrowingTest do
  @moduledoc """
  唐门暗器学习门槛迁移（C 相位，tangmen-throwing 真缺口补齐）。

  对照 `kungfu/skill/tangmen-throwing.c`：
  - valid_learn: force>=60 / dodge>=60 / throwing>=50 / dex>=30 / str>=30 / int>=28 / throwing>=self；
  - practice_skill 扣 qi 50 / neili 50。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.TangmenThrowing

  defp stats(force, dodge, throwing, dex, str, int, self_lvl),
    do: %{
      skills: %{
        "force" => force,
        "dodge" => dodge,
        "throwing" => throwing,
        "tangmen-throwing" => self_lvl
      },
      dex: dex,
      str: str,
      int: int
    }

  describe "valid_learn/2 学习门槛（LPC force>=60 / dodge>=60 / throwing>=50 / dex>=30 / str>=30 / int>=28 / throwing>=self）" do
    test "force < 60 被拒（内功心法火候不够）" do
      assert TangmenThrowing.valid_learn(stats(30, 200, 200, 40, 40, 40, 0), nil) ==
               {:error, "你的内功心法火候不够，无法学唐门暗器。\n"}
    end

    test "dodge < 60 被拒（轻功火候不够）" do
      assert TangmenThrowing.valid_learn(stats(200, 30, 200, 40, 40, 40, 0), nil) ==
               {:error, "你的轻功火候不够，无法领悟唐门暗器。\n"}
    end

    test "throwing < 50 被拒（暗器技能不够娴熟）" do
      assert TangmenThrowing.valid_learn(stats(200, 200, 30, 40, 40, 40, 0), nil) ==
               {:error, "你的暗器技能不够娴熟，无法领悟唐门暗器。\n"}
    end

    test "dex < 30 被拒（身法不够灵巧）" do
      assert TangmenThrowing.valid_learn(stats(200, 200, 200, 20, 40, 40, 0), nil) ==
               {:error, "你的身法不够灵巧，无法学习唐门暗器。\n"}
    end

    test "str < 30 被拒（臂力不够）" do
      assert TangmenThrowing.valid_learn(stats(200, 200, 200, 40, 20, 40, 0), nil) ==
               {:error, "你的臂力不够，多练练本门的基本手法吧。\n"}
    end

    test "int < 28 被拒（悟性不够）" do
      assert TangmenThrowing.valid_learn(stats(200, 200, 200, 40, 40, 20, 0), nil) ==
               {:error, "你的悟性不够，无法领悟唐门暗器秘诀。\n"}
    end

    test "throwing < tangmen-throwing 被拒（基本暗器水平有限）" do
      assert TangmenThrowing.valid_learn(stats(200, 200, 200, 40, 40, 40, 250), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更高深的唐门暗器。\n"}
    end

    test "七项全满足则放行" do
      assert TangmenThrowing.valid_learn(stats(200, 200, 200, 40, 40, 40, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert TangmenThrowing.practice_cost() == %{qi: 50, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("tangmen-throwing") == TangmenThrowing
    end
  end
end

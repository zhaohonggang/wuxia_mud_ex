defmodule Kantele.Combat.SkillsPidiShenzhenTest do
  @moduledoc """
  辟地神针学习门槛迁移（C 相位，pidi-shenzhen 真缺口补齐）。

  对照 `kungfu/skill/pidi-shenzhen.c`：
  - valid_learn: throwing>=40 / throwing>=pidi-shenzhen；
  - practice_skill 扣 qi 70 / neili 50。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.PidiShenzhen

  defp stats(throwing, self_lvl),
    do: %{skills: %{"throwing" => throwing, "pidi-shenzhen" => self_lvl}}

  describe "valid_learn/2 学习门槛（LPC throwing>=40 / throwing>=self）" do
    test "throwing < 40 被拒（暗器技能不够娴熟）" do
      assert PidiShenzhen.valid_learn(stats(20, 0), nil) ==
               {:error, "你的暗器技能不够娴熟。\n"}
    end

    test "throwing < pidi-shenzhen 被拒（基本暗器水平有限）" do
      assert PidiShenzhen.valid_learn(stats(100, 150), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更精妙的辟地神针。\n"}
    end

    test "两项全满足则放行" do
      assert PidiShenzhen.valid_learn(stats(100, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 70 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert PidiShenzhen.practice_cost() == %{qi: 70, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("pidi-shenzhen") == PidiShenzhen
    end
  end
end

defmodule Kantele.Combat.SkillsJinbiaoJueTest do
  @moduledoc """
  金镖诀学习门槛迁移（C 相位，jinbiao-jue 真缺口补齐）。

  对照 `kungfu/skill/jinbiao-jue.c`：
  - valid_learn: throwing>=10 / throwing>=jinbiao-jue；
  - practice_skill 扣 qi 70 / neili 50。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JinbiaoJue

  defp stats(throwing, self_lvl),
    do: %{skills: %{"throwing" => throwing, "jinbiao-jue" => self_lvl}}

  describe "valid_learn/2 学习门槛（LPC throwing>=10 / throwing>=self）" do
    test "throwing < 10 被拒（暗器技能不够娴熟）" do
      assert JinbiaoJue.valid_learn(stats(5, 0), nil) ==
               {:error, "你的暗器技能不够娴熟。\n"}
    end

    test "throwing < jinbiao-jue 被拒（基本暗器水平有限）" do
      assert JinbiaoJue.valid_learn(stats(50, 60), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更精妙的金镖诀。\n"}
    end

    test "两项全满足则放行" do
      assert JinbiaoJue.valid_learn(stats(50, 40), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 70 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert JinbiaoJue.practice_cost() == %{qi: 70, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jinbiao-jue") == JinbiaoJue
    end
  end
end

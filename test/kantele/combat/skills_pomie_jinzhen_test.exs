defmodule Kantele.Combat.SkillsPomieJinzhenTest do
  @moduledoc """
  破灭金针学习门槛迁移（C 相位，pomie-jinzhen 真缺口补齐）。

  对照 `kungfu/skill/pomie-jinzhen.c`：
  - valid_learn: force>=90 / dodge>=90 / dex>=25 / throwing>=pomie-jinzhen；
  - practice_skill 扣 qi 45 / neili 45。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.PomieJinzhen

  defp stats(force, dodge, dex, throwing, self_lvl),
    do: %{
      skills: %{
        "force" => force,
        "dodge" => dodge,
        "throwing" => throwing,
        "pomie-jinzhen" => self_lvl
      },
      dex: dex
    }

  describe "valid_learn/2 学习门槛（LPC force>=90 / dodge>=90 / dex>=25 / throwing>=self）" do
    test "force < 90 被拒（内功火候不够）" do
      assert PomieJinzhen.valid_learn(stats(50, 200, 50, 200, 0), nil) ==
               {:error, "你的内功火候不够，难以修炼破灭金针。\n"}
    end

    test "dodge < 90 被拒（轻功火候不够）" do
      assert PomieJinzhen.valid_learn(stats(200, 50, 50, 200, 0), nil) ==
               {:error, "你的轻功火候不够，难以修炼破灭金针。\n"}
    end

    test "dex < 25 被拒（身法灵动不够）" do
      assert PomieJinzhen.valid_learn(stats(200, 200, 20, 200, 0), nil) ==
               {:error, "你的身法灵动不够，难以修炼破灭金针。\n"}
    end

    test "throwing < pomie-jinzhen 被拒（基本暗器水平有限）" do
      assert PomieJinzhen.valid_learn(stats(200, 200, 50, 200, 250), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更高深的破灭金针。\n"}
    end

    test "四项全满足则放行" do
      assert PomieJinzhen.valid_learn(stats(200, 200, 50, 200, 100), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 45）" do
    test "返回 LPC 一致的消耗" do
      assert PomieJinzhen.practice_cost() == %{qi: 45, neili: 45}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("pomie-jinzhen") == PomieJinzhen
    end
  end
end

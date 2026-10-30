defmodule Kantele.Combat.SkillsSunFingerTest do
  @moduledoc """
  一阳指学习门槛迁移（C 相位，sun-finger 真缺口补齐）。

  对照 `kungfu/skill/sun-finger.c`：
  - valid_learn: 须男性 / str>=34 / dex>=30 / force>=240 / max_neili>=2000 /
    finger>=150 / finger>=sun-finger；「须空手」由 practice 流程把关；
  - practice_skill 扣 qi 60 / neili 100。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SunFinger

  defp stats(str, dex, force, finger, self_lvl) do
    %{
      str: str,
      dex: dex,
      skills: %{"force" => force, "finger" => finger, "sun-finger" => self_lvl}
    }
  end

  defp char(gender, mn), do: %{meta: %{vitals: %{max_neili: mn}, env: %{gender: gender}}}

  # 默认全达标：str 34 / dex 30 / force 240 / finger 150 / self 10
  defp ok_stats, do: stats(34, 30, 240, 150, 10)

  describe "valid_learn/2 学习门槛" do
    test "非男性被拒（纯阳玄功）" do
      assert SunFinger.valid_learn(ok_stats(), char("女性", 2000)) ==
               {:error, "一阳指乃是纯阳玄功，你如何可以修习？\n"}
    end

    test "无性被拒（纯阳玄功）" do
      assert SunFinger.valid_learn(ok_stats(), char("无性", 2000)) ==
               {:error, "一阳指乃是纯阳玄功，你如何可以修习？\n"}
    end

    test "str < 34 被拒（先天膂力孱弱）" do
      assert SunFinger.valid_learn(stats(33, 30, 240, 150, 10), char("男性", 2000)) ==
               {:error, "你的先天膂力孱弱，无法领会一阳指。\n"}
    end

    test "dex < 30 被拒（先天身法孱弱）" do
      assert SunFinger.valid_learn(stats(34, 29, 240, 150, 10), char("男性", 2000)) ==
               {:error, "你的先天身法孱弱，无法修炼一阳指。\n"}
    end

    test "force < 240 被拒（内功火候不够）" do
      assert SunFinger.valid_learn(stats(34, 30, 239, 150, 10), char("男性", 2000)) ==
               {:error, "你的内功火候不够，无法学一阳指。\n"}
    end

    test "max_neili < 2000 被拒（内力太弱）" do
      assert SunFinger.valid_learn(ok_stats(), char("男性", 1999)) ==
               {:error, "你的内力太弱，无法练一阳指。\n"}
    end

    test "finger < 150 被拒（基本指法火候不够）" do
      assert SunFinger.valid_learn(stats(34, 30, 240, 149, 10), char("男性", 2000)) ==
               {:error, "你的基本指法火候不够，无法学一阳指。\n"}
    end

    test "finger < sun-finger 被拒（基本指法水平有限）" do
      assert SunFinger.valid_learn(stats(34, 30, 240, 200, 250), char("男性", 2000)) ==
               {:error, "你的基本指法水平有限，无法领会更高深的一阳指。\n"}
    end

    test "全部门槛满足则放行" do
      assert SunFinger.valid_learn(ok_stats(), char("男性", 2000)) == :ok
    end

    test "character 为 nil 时按男性处理并跳过 max_neili 检查" do
      assert SunFinger.valid_learn(ok_stats(), nil) == :ok
    end

    test "character 无 meta/env/vitals 时按男性处理并跳过 max_neili 检查" do
      assert SunFinger.valid_learn(ok_stats(), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 60 / neili 100）" do
    test "返回 LPC 一致的消耗" do
      assert SunFinger.practice_cost() == %{qi: 60, neili: 100}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("sun-finger") == SunFinger
    end
  end
end

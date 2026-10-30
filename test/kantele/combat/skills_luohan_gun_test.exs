defmodule Kantele.Combat.SkillsLuohanGunTest do
  @moduledoc """
  罗汉棍法学习门槛迁移（C 相位，luohan-gun 真缺口补齐）。

  对照 `kungfu/skill/luohan-gun.c`：
  - valid_learn: max_neili>=1200 / force>=100 / club>=100 / club>=luohan-gun；
  - practice_skill 扣 qi 62 / neili 61（须持棍，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LuohanGun

  defp stats(force, club, luohan),
    do: %{skills: %{"force" => force, "club" => club, "luohan-gun" => luohan}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1200 / force>=100 / club>=100 / club>=luohan-gun）" do
    test "max_neili < 1200 被拒（内力不够）" do
      assert LuohanGun.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 100 被拒（内功火候太浅）" do
      assert LuohanGun.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "club < 100 被拒（基本棍法水平不足）" do
      assert LuohanGun.valid_learn(stats(200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本棍法水平还不足以学习十八罗汉棍法。\n"}
    end

    test "club < luohan-gun 被拒（基本棍法水平有限）" do
      assert LuohanGun.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本棍法水平有限，无法领会更高深的十八罗汉棍法。\n"}
    end

    test "四项全满足则放行" do
      assert LuohanGun.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert LuohanGun.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert LuohanGun.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 62 / neili 61）" do
    test "返回 LPC 一致的消耗" do
      assert LuohanGun.practice_cost() == %{qi: 62, neili: 61}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("luohan-gun") == LuohanGun
    end
  end
end

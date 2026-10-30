defmodule Kantele.Combat.SkillsJinguanYusuoTest do
  @moduledoc """
  金刚玉锁学习门槛迁移（C 相位，jinguan-yusuo 真缺口补齐）。

  对照 `kungfu/skill/jinguan-yusuo.c`：
  - valid_learn: taoism>=150 / force>=150 / parry>=150 / max_neili>=1800 /
    force>=jinguan-yusuo / parry>=jinguan-yusuo；
  - practice_skill 扣 qi 80 / neili 90；其「自身<200 则拒」为 practice 专属门，当前未建模。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JinguanYusuo

  defp stats(taoism, force, parry, self_lvl) do
    %{
      skills: %{
        "taoism" => taoism,
        "force" => force,
        "parry" => parry,
        "jinguan-yusuo" => self_lvl
      }
    }
  end

  defp char(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛" do
    test "taoism < 150 被拒（道学理解不够深入）" do
      assert JinguanYusuo.valid_learn(stats(149, 200, 200, 10), char(2000)) ==
               {:error, "你对道学理解不够深入，无法学习金关玉锁。\n"}
    end

    test "force < 150 被拒（基本内功火候不够）" do
      assert JinguanYusuo.valid_learn(stats(200, 149, 200, 10), char(2000)) ==
               {:error, "你的基本内功火候不够，无法学习金关玉锁。\n"}
    end

    test "parry < 150 被拒（基本招架火候不够）" do
      assert JinguanYusuo.valid_learn(stats(200, 200, 149, 10), char(2000)) ==
               {:error, "你的基本招架火候不够，无法学习金关玉锁。\n"}
    end

    test "max_neili < 1800 被拒（内力修为不足）" do
      assert JinguanYusuo.valid_learn(stats(200, 200, 200, 10), char(1799)) ==
               {:error, "你目前的内力修为不足，无法学习金关玉锁。\n"}
    end

    test "force < 本技能被拒（基本内功水平有限）" do
      assert JinguanYusuo.valid_learn(stats(200, 200, 200, 250), char(2000)) ==
               {:error, "你的基本内功水平有限，无法领会更高深的金关玉锁。\n"}
    end

    test "parry < 本技能被拒（基本招架水平有限）" do
      assert JinguanYusuo.valid_learn(stats(200, 300, 200, 250), char(2000)) ==
               {:error, "你的基本招架水平有限，无法领会更高深的金关玉锁。\n"}
    end

    test "全部门槛满足则放行" do
      assert JinguanYusuo.valid_learn(stats(150, 150, 150, 10), char(1800)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert JinguanYusuo.valid_learn(stats(200, 200, 200, 10), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JinguanYusuo.valid_learn(stats(200, 200, 200, 10), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 80 / neili 90）" do
    test "返回 LPC 一致的消耗" do
      assert JinguanYusuo.practice_cost() == %{qi: 80, neili: 90}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jinguan-yusuo") == JinguanYusuo
    end
  end
end

defmodule Kantele.Combat.SkillsJinsheJianTest do
  @moduledoc """
  金蛇剑法学习门槛迁移（C 相位，jinshe-jian 真缺口补齐）。

  对照 `kungfu/skill/jinshe-jian.c`：
  - valid_learn: int>=33 / dex>=33 / max_neili>=4000 / force>=200 / dodge>=240 / sword>=220 / martial-cognize>=220 / sword>=jinshe-jian；
  - practice_skill 扣 qi 70 / neili 70（须持剑，由 practice 流程把关；alignment 注释门控未建模）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.JinsheJian

  defp stats(int, dex, force, dodge, sword, mc, jinshe),
    do: %{
      int: int,
      dex: dex,
      skills: %{
        "force" => force,
        "dodge" => dodge,
        "sword" => sword,
        "martial-cognize" => mc,
        "jinshe-jian" => jinshe
      }
    }

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC int>=33 / dex>=33 / max_neili>=4000 / force>=200 / dodge>=240 / sword>=220 / martial-cognize>=220 / sword>=jinshe-jian）" do
    test "int < 33 被拒（先天悟性不足）" do
      assert JinsheJian.valid_learn(stats(10, 50, 300, 300, 300, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你先天悟性不足，无法领悟金蛇剑法。\n"}
    end

    test "dex < 33 被拒（先天身法不足）" do
      assert JinsheJian.valid_learn(stats(50, 10, 300, 300, 300, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你先天身法不足，无法修习金蛇剑法。\n"}
    end

    test "max_neili < 4000 被拒（内力修为不够）" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 300, 300, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够，没有办法练金蛇剑法。\n"}
    end

    test "force < 200 被拒（基本内功火候不够）" do
      assert JinsheJian.valid_learn(stats(50, 50, 10, 300, 300, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你的基本内功火候不够，没有办法练金蛇剑法。\n"}
    end

    test "dodge < 240 被拒（基本轻功火候不够）" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 10, 300, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你的基本轻功火候不够，没有办法练金蛇剑法。\n"}
    end

    test "sword < 220 被拒（基本剑法火候不够）" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 10, 300, 50), char_with_max_neili(9999)) ==
               {:error, "你的基本剑法火候不够，没有办法练金蛇剑法。\n"}
    end

    test "martial-cognize < 220 被拒（武学修养不足）" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 300, 10, 50), char_with_max_neili(9999)) ==
               {:error, "你的武学修养不足，没有办法领悟金蛇剑法。\n"}
    end

    test "sword < jinshe-jian 被拒（基本剑法水平有限）" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 300, 300, 150), char_with_max_neili(9999)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的金蛇剑法。\n"}
    end

    test "八项全满足则放行" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 300, 300, 50), char_with_max_neili(9999)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 300, 300, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert JinsheJian.valid_learn(stats(50, 50, 300, 300, 300, 300, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 70 / neili 70）" do
    test "返回 LPC 一致的消耗" do
      assert JinsheJian.practice_cost() == %{qi: 70, neili: 70}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("jinshe-jian") == JinsheJian
    end
  end
end

defmodule Kantele.Combat.SkillsTaijiJianTest do
  @moduledoc """
  太极剑法学习门槛迁移（C 相位，taiji-jian 真缺口补齐）。

  对照 `kungfu/skill/taiji-jian.c`：
  - valid_learn: int>=26 / max_neili>=1500 / force>=200 / taiji-quan>=100 /
    sword>=100 / sword>=taiji-jian；
  - practice_skill 扣 qi 50 / neili 64（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.TaijiJian

  defp stats(int, force, taijiquan, sword, taijijian),
    do: %{
      int: int,
      skills: %{
        "force" => force,
        "taiji-quan" => taijiquan,
        "sword" => sword,
        "taiji-jian" => taijijian
      }
    }

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛" do
    test "int < 26 被拒（悟性太差）" do
      assert TaijiJian.valid_learn(stats(10, 300, 200, 200, 50), char_with_max_neili(3000)) ==
               {:error, "你先天悟性太差，难以领会太极剑的要诣。\n"}
    end

    test "max_neili < 1500 被拒（内力不够）" do
      assert TaijiJian.valid_learn(stats(30, 300, 200, 200, 50), char_with_max_neili(1000)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 200 被拒（内功火候太浅）" do
      assert TaijiJian.valid_learn(stats(30, 100, 200, 200, 50), char_with_max_neili(3000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "taiji-quan < 100 被拒（太极拳火候太浅）" do
      assert TaijiJian.valid_learn(stats(30, 300, 50, 200, 50), char_with_max_neili(3000)) ==
               {:error, "你的太极拳火候太浅。\n"}
    end

    test "sword < 100 被拒（基本剑法水平有限·无法修炼）" do
      assert TaijiJian.valid_learn(stats(30, 300, 200, 50, 50), char_with_max_neili(3000)) ==
               {:error, "你的基本剑法水平有限，无法修炼太极剑法。\n"}
    end

    test "sword < taiji-jian 被拒（基本剑法水平有限·无法领会更高深·太级）" do
      assert TaijiJian.valid_learn(stats(30, 300, 200, 100, 150), char_with_max_neili(3000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的太级剑法。\n"}
    end

    test "全部满足则放行" do
      assert TaijiJian.valid_learn(stats(30, 300, 200, 200, 50), char_with_max_neili(3000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert TaijiJian.valid_learn(stats(30, 100, 200, 200, 50), nil) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert TaijiJian.valid_learn(stats(30, 100, 200, 200, 50), %{}) ==
               {:error, "你的内功火候太浅。\n"}
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 64）" do
    test "返回 LPC 一致的消耗" do
      assert TaijiJian.practice_cost() == %{qi: 50, neili: 64}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("taiji-jian") == TaijiJian
    end
  end
end

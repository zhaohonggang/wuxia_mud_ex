defmodule Kantele.Combat.SkillsMiaojiaJianTest do
  @moduledoc """
  苗家剑法学习门槛迁移（C 相位，miaojia-jian 真缺口补齐）。

  对照 `kungfu/skill/miaojia-jian.c`：
  - valid_learn: 已学 daojian-guizhen 则拒 / max_neili>=1300 / force>=150 / sword>=120 /
    sword>=miaojia-jian；
  - practice_skill 扣 qi 53 / neili 84（须持剑由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.MiaojiaJian

  defp stats(daojian, force, sword, self_lvl) do
    %{
      skills: %{
        "daojian-guizhen" => daojian,
        "force" => force,
        "sword" => sword,
        "miaojia-jian" => self_lvl
      }
    }
  end

  defp char(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛" do
    test "已学 daojian-guizhen 则拒（刀剑合一互斥）" do
      assert MiaojiaJian.valid_learn(stats(1, 200, 200, 10), char(2000)) ==
               {:error, "你已经将苗家剑法和胡家刀法二者合一了。\n"}
    end

    test "max_neili < 1300 被拒（内力不够）" do
      assert MiaojiaJian.valid_learn(stats(0, 200, 200, 10), char(1299)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 150 被拒（内功火候太浅）" do
      assert MiaojiaJian.valid_learn(stats(0, 149, 200, 10), char(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "sword < 120 被拒（基本剑法火候不够）" do
      assert MiaojiaJian.valid_learn(stats(0, 200, 119, 10), char(2000)) ==
               {:error, "你的基本剑法火候不够，无法学习苗家剑法。\n"}
    end

    test "sword < miaojia-jian 被拒（基本剑法水平有限）" do
      assert MiaojiaJian.valid_learn(stats(0, 200, 200, 250), char(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的苗家剑法。\n"}
    end

    test "全部门槛满足则放行" do
      assert MiaojiaJian.valid_learn(stats(0, 150, 120, 10), char(1300)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert MiaojiaJian.valid_learn(stats(0, 200, 200, 10), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert MiaojiaJian.valid_learn(stats(0, 200, 200, 10), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 53 / neili 84）" do
    test "返回 LPC 一致的消耗" do
      assert MiaojiaJian.practice_cost() == %{qi: 53, neili: 84}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("miaojia-jian") == MiaojiaJian
    end
  end
end

defmodule Kantele.Combat.SkillsSuxinJianTest do
  @moduledoc """
  素心剑法（玉女素心剑）学习门槛迁移（C 相位，suxin-jian 真缺口补齐）。

  对照 `kungfu/skill/suxin-jian.c`：
  - valid_learn: gender=="女性" / int>=28 / force>=100 / sword>=100 / max_neili>=2000 / sword>=suxin-jian；
  - practice_skill 扣 qi 60 / neili 60（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SuxinJian

  defp stats(int, force, sword, suxin),
    do: %{int: int, skills: %{"force" => force, "sword" => sword, "suxin-jian" => suxin}}

  defp char_female_with_max_neili(mn),
    do: %{meta: %{env: %{gender: "女性"}, vitals: %{max_neili: mn}}}

  defp char_male(), do: %{meta: %{env: %{gender: "男性"}}}

  describe "valid_learn/2 学习门槛（LPC gender==女性 / int>=28 / force>=100 / sword>=100 / max_neili>=2000 / sword>=suxin-jian）" do
    test "男性被拒（玉女素心剑只有女性能练）" do
      assert SuxinJian.valid_learn(stats(50, 200, 200, 50), char_male()) ==
               {:error, "玉女素心剑只有女性能练。\n"}
    end

    test "character 为 nil → 性别缺省男性被拒" do
      assert SuxinJian.valid_learn(stats(50, 200, 200, 50), nil) ==
               {:error, "玉女素心剑只有女性能练。\n"}
    end

    test "int < 28 被拒（先天悟性不够，女性、高 max_neili）" do
      assert SuxinJian.valid_learn(stats(10, 200, 200, 50), char_female_with_max_neili(2000)) ==
               {:error, "你的先天悟性不够，无法学习玉女素心剑。\n"}
    end

    test "force < 100 被拒（内功火候不到）" do
      assert SuxinJian.valid_learn(stats(50, 10, 200, 50), char_female_with_max_neili(2000)) ==
               {:error, "你的内功火候不到，无法学习玉女素心剑。\n"}
    end

    test "sword < 100 被拒（基本剑法水平太低）" do
      assert SuxinJian.valid_learn(stats(50, 200, 5, 50), char_female_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平太低，无法学习玉女素心剑。\n"}
    end

    test "max_neili < 2000 被拒（内力修为不够，女性、其余达标）" do
      assert SuxinJian.valid_learn(stats(50, 200, 200, 50), char_female_with_max_neili(20)) ==
               {:error, "你的内力修为不够，不能学习玉女素心剑。\n"}
    end

    test "sword < suxin-jian 被拒（基本剑法水平有限）" do
      assert SuxinJian.valid_learn(stats(50, 200, 200, 150), char_female_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的玉女素心剑。\n"}
    end

    test "女性且各项达标则放行" do
      assert SuxinJian.valid_learn(stats(50, 200, 200, 50), char_female_with_max_neili(2000)) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 60 / neili 60）" do
    test "返回 LPC 一致的消耗" do
      assert SuxinJian.practice_cost() == %{qi: 60, neili: 60}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("suxin-jian") == SuxinJian
    end
  end
end

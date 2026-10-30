defmodule Kantele.Combat.SkillsRuanhongZhusuoTest do
  @moduledoc """
  软红蛛索学习门槛迁移（C 相位，ruanhong-zhusuo 真缺口补齐）。

  对照 `kungfu/skill/ruanhong-zhusuo.c`：
  - valid_learn: max_neili>=1000 / force>=150 / whip>=100 / whip>=ruanhong-zhusuo；
  - practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.RuanhongZhusuo

  defp stats(force, whip, self_lvl),
    do: %{skills: %{"force" => force, "whip" => whip, "ruanhong-zhusuo" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1000 / force>=150 / whip>=100 / whip>=self）" do
    test "max_neili < 1000 被拒（内力不足）" do
      assert RuanhongZhusuo.valid_learn(stats(200, 200, 50), char_with_max_neili(500)) ==
               {:error, "你的内力不足，没有办法练软红蛛索，多练些内力再来吧。\n"}
    end

    test "force < 150 被拒（内功火候太浅）" do
      assert RuanhongZhusuo.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅，没有办法练软红蛛索。\n"}
    end

    test "whip < 100 被拒（基本鞭法火候太浅）" do
      assert RuanhongZhusuo.valid_learn(stats(200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法火候太浅，没有办法练软红蛛索。\n"}
    end

    test "whip < ruanhong-zhusuo 被拒（基本鞭法水平还不够）" do
      assert RuanhongZhusuo.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法水平还不够，无法领会更高深的软红蛛索。\n"}
    end

    test "四项全满足则放行" do
      assert RuanhongZhusuo.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert RuanhongZhusuo.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 75 / neili 85）" do
    test "返回 LPC 一致的消耗" do
      assert RuanhongZhusuo.practice_cost() == %{qi: 75, neili: 85}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("ruanhong-zhusuo") == RuanhongZhusuo
    end
  end
end

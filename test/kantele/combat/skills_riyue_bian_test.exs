defmodule Kantele.Combat.SkillsRiyueBianTest do
  @moduledoc """
  日月鞭法学习门槛迁移（C 相位，riyue-bian 真缺口补齐）。

  对照 `kungfu/skill/riyue-bian.c`：
  - valid_learn: int>=30 / con>=32 / max_neili>=1000 / force>=150 / whip>=100 / whip>=riyue-bian；
  - practice_skill 扣 qi 75 / neili 85（须持鞭，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.RiyueBian

  defp stats(int, con, force, whip, self_lvl),
    do: %{
      skills: %{"force" => force, "whip" => whip, "riyue-bian" => self_lvl},
      int: int,
      con: con
    }

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC int>=30 / con>=32 / max_neili>=1000 / force>=150 / whip>=100 / whip>=self）" do
    test "int < 30 被拒（过于艰深难以理解）" do
      assert RiyueBian.valid_learn(stats(20, 40, 200, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你觉得日月鞭法过于艰深，难以理解。\n"}
    end

    test "con < 32 被拒（先天根骨孱弱）" do
      assert RiyueBian.valid_learn(stats(40, 20, 200, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的先天根骨孱弱，无法运转日月鞭法。\n"}
    end

    test "max_neili < 1000 被拒（内力不足）" do
      assert RiyueBian.valid_learn(stats(40, 40, 200, 200, 50), char_with_max_neili(500)) ==
               {:error, "你的内力不足，没有办法练日月鞭法，多练些内力再来吧。\n"}
    end

    test "force < 150 被拒（内功火候太浅）" do
      assert RiyueBian.valid_learn(stats(40, 40, 50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅，没有办法练日月鞭法。\n"}
    end

    test "whip < 100 被拒（基本鞭法火候太浅）" do
      assert RiyueBian.valid_learn(stats(40, 40, 200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法火候太浅，没有办法练日月鞭法。\n"}
    end

    test "whip < riyue-bian 被拒（基本鞭法水平还不够）" do
      assert RiyueBian.valid_learn(stats(40, 40, 200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法水平还不够，无法领会更高深的日月鞭法。\n"}
    end

    test "六项全满足则放行" do
      assert RiyueBian.valid_learn(stats(40, 40, 200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert RiyueBian.valid_learn(stats(40, 40, 200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 75 / neili 85）" do
    test "返回 LPC 一致的消耗" do
      assert RiyueBian.practice_cost() == %{qi: 75, neili: 85}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("riyue-bian") == RiyueBian
    end
  end
end

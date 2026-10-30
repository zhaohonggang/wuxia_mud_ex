defmodule Kantele.Combat.SkillsLongchengShendaoTest do
  @moduledoc """
  龙城神刀学习门槛迁移（C 相位，longcheng-shendao 真缺口补齐）。

  对照 `kungfu/skill/longcheng-shendao.c`：
  - valid_learn: max_neili>=1000 / force>=150 / blade>=80 / blade>=longcheng-shendao；
  - practice_skill 扣 qi 65 / neili 68（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LongchengShendao

  defp stats(force, blade, self_lvl),
    do: %{skills: %{"force" => force, "blade" => blade, "longcheng-shendao" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1000 / force>=150 / blade>=80 / blade>=self）" do
    test "max_neili < 1000 被拒（内力不够）" do
      assert LongchengShendao.valid_learn(stats(200, 200, 50), char_with_max_neili(500)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 150 被拒（内功火候太浅）" do
      assert LongchengShendao.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "blade < 80 被拒（基本刀法火候不够）" do
      assert LongchengShendao.valid_learn(stats(200, 50, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法火候不够。\n"}
    end

    test "blade < longcheng-shendao 被拒（刀法水平有限）" do
      assert LongchengShendao.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的刀法水平有限，无法领会更高深的龙城神刀。\n"}
    end

    test "四项全满足则放行" do
      assert LongchengShendao.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert LongchengShendao.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 65 / neili 68）" do
    test "返回 LPC 一致的消耗" do
      assert LongchengShendao.practice_cost() == %{qi: 65, neili: 68}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("longcheng-shendao") == LongchengShendao
    end
  end
end

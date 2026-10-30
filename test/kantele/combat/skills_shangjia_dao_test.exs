defmodule Kantele.Combat.SkillsShangjiaDaoTest do
  @moduledoc """
  商家刀法学习门槛迁移（C 相位，shangjia-dao 真缺口补齐）。

  对照 `kungfu/skill/shangjia-dao.c`：
  - valid_learn: max_neili>=350 / force>=50 / blade>=shangjia-dao（无绝对刀法下限）；
  - practice_skill 扣 qi 50 / neili 35（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ShangjiaDao

  defp stats(force, blade, shangjia),
    do: %{skills: %{"force" => force, "blade" => blade, "shangjia-dao" => shangjia}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=350 / force>=50 / blade>=shangjia-dao）" do
    test "max_neili < 350 被拒（内力不够）" do
      assert ShangjiaDao.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 50 被拒（基本内功火候太浅）" do
      assert ShangjiaDao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本内功火候太浅。\n"}
    end

    test "blade < shangjia-dao 被拒（基本刀法火候有限）" do
      assert ShangjiaDao.valid_learn(stats(200, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法火候有限，无法领会更高深的商家刀法。\n"}
    end

    test "三项全满足则放行" do
      assert ShangjiaDao.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert ShangjiaDao.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert ShangjiaDao.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 50 / neili 35）" do
    test "返回 LPC 一致的消耗" do
      assert ShangjiaDao.practice_cost() == %{qi: 50, neili: 35}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("shangjia-dao") == ShangjiaDao
    end
  end
end

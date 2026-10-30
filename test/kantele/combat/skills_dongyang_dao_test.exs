defmodule Kantele.Combat.SkillsDongyangDaoTest do
  @moduledoc """
  东洋刀法学习门槛迁移（C 相位，dongyang-dao 真缺口补齐）。

  对照 `kungfu/skill/dongyang-dao.c`：
  - valid_learn: max_neili>=100 / force>=30 / blade>=dongyang-dao（LPC 原文重复一行，合并为一）；
  - practice_skill 扣 qi 60 / neili 42（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DongyangDao

  defp stats(force, blade, dongyang),
    do: %{skills: %{"force" => force, "blade" => blade, "dongyang-dao" => dongyang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / force>=30 / blade>=dongyang-dao）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert DongyangDao.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 30 被拒（内功火候不够）" do
      assert DongyangDao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够。\n"}
    end

    test "blade < dongyang-dao 被拒（基本刀法水平有限）" do
      assert DongyangDao.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法领会更高深的东洋刀法。\n"}
    end

    test "三项全满足则放行" do
      assert DongyangDao.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert DongyangDao.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DongyangDao.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 60 / neili 42）" do
    test "返回 LPC 一致的消耗" do
      assert DongyangDao.practice_cost() == %{qi: 60, neili: 42}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("dongyang-dao") == DongyangDao
    end
  end
end

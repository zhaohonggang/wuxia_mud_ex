defmodule Kantele.Combat.SkillsPoguangDaoTest do
  @moduledoc """
  破光刀法学习门槛迁移（C 相位，poguang-dao 真缺口补齐）。

  对照 `kungfu/skill/poguang-dao.c`：
  - valid_learn: max_neili>=800 / force>=120 / blade>=100 / blade>=poguang-dao；
  - practice_skill 扣 qi 40 / neili 50（LPC 原文 valid_learn 查刀、practice 查剑，不一致；武器由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.PoguangDao

  defp stats(force, blade, poguang),
    do: %{skills: %{"force" => force, "blade" => blade, "poguang-dao" => poguang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=800 / force>=120 / blade>=100 / blade>=poguang-dao）" do
    test "max_neili < 800 被拒（内力修为不够）" do
      assert PoguangDao.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够，无法学习破光刀法。\n"}
    end

    test "force < 120 被拒（内功火候太浅）" do
      assert PoguangDao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅，无法学习破光刀法。\n"}
    end

    test "blade < 100 被拒（基本刀法火候不够）" do
      assert PoguangDao.valid_learn(stats(200, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法火候不够，无法学习破光刀法。\n"}
    end

    test "blade < poguang-dao 被拒（基本剑法水平有限）" do
      assert PoguangDao.valid_learn(stats(200, 200, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候有限，无法领会更高深的破光刀法。\n"}
    end

    test "四项全满足则放行" do
      assert PoguangDao.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert PoguangDao.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert PoguangDao.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 40 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert PoguangDao.practice_cost() == %{qi: 40, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("poguang-dao") == PoguangDao
    end
  end
end

defmodule Kantele.Combat.SkillsChuangwangDaoTest do
  @moduledoc """
  闯王刀法学习门槛迁移（C 相位，chuangwang-dao 真缺口补齐）。

  对照 `kungfu/skill/chuangwang-dao.c`：
  - valid_learn: max_neili>=50 / force>=10 / blade>=chuangwang-dao；
  - practice_skill 扣 qi 45 / neili 43（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ChuangwangDao

  defp stats(force, blade, chuangwang),
    do: %{skills: %{"force" => force, "blade" => blade, "chuangwang-dao" => chuangwang}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=50 / force>=10 / blade>=chuangwang-dao）" do
    test "max_neili < 50 被拒（内力修为不够）" do
      assert ChuangwangDao.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够。\n"}
    end

    test "force < 10 被拒（内功火候太浅）" do
      assert ChuangwangDao.valid_learn(stats(5, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "blade < chuangwang-dao 被拒（基本刀法水平有限）" do
      assert ChuangwangDao.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法领会更高深的闯王刀法。\n"}
    end

    test "三项全满足则放行" do
      assert ChuangwangDao.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert ChuangwangDao.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert ChuangwangDao.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 43）" do
    test "返回 LPC 一致的消耗" do
      assert ChuangwangDao.practice_cost() == %{qi: 45, neili: 43}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("chuangwang-dao") == ChuangwangDao
    end
  end
end

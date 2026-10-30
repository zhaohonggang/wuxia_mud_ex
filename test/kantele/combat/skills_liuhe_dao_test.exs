defmodule Kantele.Combat.SkillsLiuheDaoTest do
  @moduledoc """
  六合刀法学习门槛迁移（C 相位，liuhe-dao 真缺口补齐）。

  对照 `kungfu/skill/liuhe-dao.c`：
  - valid_learn: max_neili>=200 / force>=50 / blade>=liuhe-dao；
  - practice_skill 扣 qi 45 / neili 43（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LiuheDao

  defp stats(force, blade, liuhe),
    do: %{skills: %{"force" => force, "blade" => blade, "liuhe-dao" => liuhe}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=200 / force>=50 / blade>=liuhe-dao）" do
    test "max_neili < 200 被拒（内力修为不够）" do
      assert LiuheDao.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为不够。\n"}
    end

    test "force < 50 被拒（内功火候太浅）" do
      assert LiuheDao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "blade < liuhe-dao 被拒（基本刀法水平有限）" do
      assert LiuheDao.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法领会更高深的六合刀法。\n"}
    end

    test "三项全满足则放行" do
      assert LiuheDao.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert LiuheDao.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert LiuheDao.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 43）" do
    test "返回 LPC 一致的消耗" do
      assert LiuheDao.practice_cost() == %{qi: 45, neili: 43}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("liuhe-dao") == LiuheDao
    end
  end
end

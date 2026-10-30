defmodule Kantele.Combat.SkillsBaguaDaoTest do
  @moduledoc """
  八卦刀法学习门槛迁移（C 相位，bagua-dao 真缺口补齐）。

  对照 `kungfu/skill/bagua-dao.c`：
  - valid_learn: max_neili>=1200 / force>=150 / blade>=100 / blade>=bagua-dao；
  - practice_skill 扣 qi 55 / neili 70（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BaguaDao

  defp stats(force, blade, bagua),
    do: %{skills: %{"force" => force, "blade" => blade, "bagua-dao" => bagua}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=1200 / force>=150 / blade>=100 / blade>=bagua-dao）" do
    test "max_neili < 1200 被拒（内力修为尚浅）" do
      assert BaguaDao.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力修为尚浅，无法练习八卦刀法。\n"}
    end

    test "force < 150 被拒（内功火候太浅）" do
      assert BaguaDao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "blade < 100 被拒（基本刀法水平有限）" do
      assert BaguaDao.valid_learn(stats(200, 5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法练习八卦刀法。\n"}
    end

    test "blade < bagua-dao 被拒（基本刀法水平有限）" do
      assert BaguaDao.valid_learn(stats(200, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法领会更高深的八卦刀法。\n"}
    end

    test "四项全满足则放行" do
      assert BaguaDao.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert BaguaDao.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert BaguaDao.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 70）" do
    test "返回 LPC 一致的消耗" do
      assert BaguaDao.practice_cost() == %{qi: 55, neili: 70}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("bagua-dao") == BaguaDao
    end
  end
end

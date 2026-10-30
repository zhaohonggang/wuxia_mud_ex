defmodule Kantele.Combat.SkillsLuoyunDaoTest do
  @moduledoc """
  落云刀法学习门槛迁移（C 相位，luoyun-dao 真缺口补齐）。

  对照 `kungfu/skill/luoyun-dao.c`：
  - valid_learn: max_neili>=400 / force>=100 / blade>=80 / blade>=luoyun-dao；
  - practice_skill 扣 qi 45 / neili 35（须持刀，由 practice 流程把关；LPC 末门文案 verbatim「孤星剑法」「基本剑法」）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LuoyunDao

  defp stats(force, blade, luoyun),
    do: %{skills: %{"force" => force, "blade" => blade, "luoyun-dao" => luoyun}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=400 / force>=100 / blade>=80 / blade>=self）" do
    test "max_neili < 400 被拒（内力修为不够）" do
      assert LuoyunDao.valid_learn(stats(200, 200, 50), char_with_max_neili(20)) ==
               {:error, "你目前的内力修为不够，没有办法练落云刀法。\n"}
    end

    test "force < 100 被拒（内功修为不够）" do
      assert LuoyunDao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功修为不够，没有办法练落云刀法。\n"}
    end

    test "blade < 80 被拒（基本剑法火候太浅）" do
      assert LuoyunDao.valid_learn(stats(200, 30, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，没有办法练落云刀法。\n"}
    end

    test "blade < luoyun-dao 被拒（基本剑法火候有限，LPC verbatim 孤星剑法）" do
      assert LuoyunDao.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候有限，无法领会更高深的孤星剑法。\n"}
    end

    test "四项全满足则放行" do
      assert LuoyunDao.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert LuoyunDao.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert LuoyunDao.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 35）" do
    test "返回 LPC 一致的消耗" do
      assert LuoyunDao.practice_cost() == %{qi: 45, neili: 35}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("luoyun-dao") == LuoyunDao
    end
  end
end

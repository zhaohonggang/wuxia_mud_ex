defmodule Kantele.Combat.SkillsDuanjiaSwordTest do
  @moduledoc """
  段家剑学习门槛迁移（C 相位，duanjia-sword 真缺口补齐）。

  对照 `kungfu/skill/duanjia-sword.c`：
  - valid_learn: max_neili>=100 / duanshi-xinfa>=20 / sword>=duanjia-sword；
  - practice_skill 扣 qi 45 / neili 36（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DuanjiaSword

  defp stats(duanshi, sword, duanjia),
    do: %{skills: %{"duanshi-xinfa" => duanshi, "sword" => sword, "duanjia-sword" => duanjia}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / duanshi-xinfa>=20 / sword>=duanjia-sword）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert DuanjiaSword.valid_learn(stats(50, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够。\n"}
    end

    test "duanshi-xinfa < 20 被拒（段氏心法火候太浅）" do
      assert DuanjiaSword.valid_learn(stats(5, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的段氏心法火候太浅。\n"}
    end

    test "sword < duanjia-sword 被拒（基本剑法火候不够）" do
      assert DuanjiaSword.valid_learn(stats(50, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候不够，无法领会更高深的段家剑法。\n"}
    end

    test "三项全满足则放行" do
      assert DuanjiaSword.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert DuanjiaSword.valid_learn(stats(50, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DuanjiaSword.valid_learn(stats(50, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 45 / neili 36）" do
    test "返回 LPC 一致的消耗" do
      assert DuanjiaSword.practice_cost() == %{qi: 45, neili: 36}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("duanjia-sword") == DuanjiaSword
    end
  end
end

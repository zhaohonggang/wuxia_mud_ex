defmodule Kantele.Combat.SkillsSuqinBeijianTest do
  @moduledoc """
  苏秦背剑学习门槛迁移（C 相位，suqin-beijian 真缺口补齐）。

  对照 `kungfu/skill/suqin-beijian.c`：
  - valid_learn: max_neili>=100 / sword>=10 / sword>=suqin-beijian；
  - practice_skill 扣 qi 33 / neili 26（须持剑，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SuqinBeijian

  defp stats(sword, suqin),
    do: %{skills: %{"sword" => sword, "suqin-beijian" => suqin}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / sword>=10 / sword>=suqin-beijian）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert SuqinBeijian.valid_learn(stats(200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力不够，无法修习苏秦背剑。\n"}
    end

    test "sword < 10 被拒（基本剑法火候太浅）" do
      assert SuqinBeijian.valid_learn(stats(5, 50), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法火候太浅，无法修习苏秦背剑。\n"}
    end

    test "sword < suqin-beijian 被拒（基本剑法水平有限）" do
      assert SuqinBeijian.valid_learn(stats(100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的苏秦背剑。\n"}
    end

    test "三项全满足则放行" do
      assert SuqinBeijian.valid_learn(stats(200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert SuqinBeijian.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert SuqinBeijian.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 33 / neili 26）" do
    test "返回 LPC 一致的消耗" do
      assert SuqinBeijian.practice_cost() == %{qi: 33, neili: 26}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("suqin-beijian") == SuqinBeijian
    end
  end
end

defmodule Kantele.Combat.SkillsHanwangQingdaoTest do
  @moduledoc """
  汉王清刀学习门槛迁移（C 相位，hanwang-qingdao 真缺口补齐）。

  对照 `kungfu/skill/hanwang-qingdao.c`：
  - valid_learn: max_neili>=100 / force>=30 / blade>=hanwang-qingdao；
  - practice_skill 扣 qi 55 / neili 58（须持刀，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HanwangQingdao

  defp stats(force, blade, self_lvl),
    do: %{skills: %{"force" => force, "blade" => blade, "hanwang-qingdao" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=100 / force>=30 / blade>=self）" do
    test "max_neili < 100 被拒（内力不够）" do
      assert HanwangQingdao.valid_learn(stats(200, 200, 50), char_with_max_neili(50)) ==
               {:error, "你的内力不够。\n"}
    end

    test "force < 30 被拒（内功火候不够）" do
      assert HanwangQingdao.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够。\n"}
    end

    test "blade < hanwang-qingdao 被拒（基本刀法水平有限）" do
      assert HanwangQingdao.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本刀法水平有限，无法领会更高深的韩王青刀。\n"}
    end

    test "三项全满足则放行" do
      assert HanwangQingdao.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert HanwangQingdao.valid_learn(stats(200, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert HanwangQingdao.valid_learn(stats(200, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 58）" do
    test "返回 LPC 一致的消耗" do
      assert HanwangQingdao.practice_cost() == %{qi: 55, neili: 58}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("hanwang-qingdao") == HanwangQingdao
    end
  end
end

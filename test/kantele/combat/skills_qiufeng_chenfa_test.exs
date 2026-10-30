defmodule Kantele.Combat.SkillsQiufengChenfaTest do
  @moduledoc """
  秋风尘法学习门槛迁移（C 相位，qiufeng-chenfa 真缺口补齐）。

  对照 `kungfu/skill/qiufeng-chenfa.c`：
  - valid_learn: max_neili>=300 / force>=60 / whip>=qiufeng-chenfa；
  - practice_skill 扣 qi 35 / neili 10（须持拂尘，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QiufengChenfa

  defp stats(force, whip, self_lvl),
    do: %{skills: %{"force" => force, "whip" => whip, "qiufeng-chenfa" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC max_neili>=300 / force>=60 / whip>=self）" do
    test "max_neili < 300 被拒（内力不足，LPC verbatim 含半角逗号）" do
      assert QiufengChenfa.valid_learn(stats(200, 200, 50), char_with_max_neili(100)) ==
               {:error, "你的内力不足，没有办法练秋风尘法, 多练些内力再来吧。\n"}
    end

    test "force < 60 被拒（内功火候太浅）" do
      assert QiufengChenfa.valid_learn(stats(30, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候太浅。\n"}
    end

    test "whip < qiufeng-chenfa 被拒（基本鞭法火候不足）" do
      assert QiufengChenfa.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本鞭法火候不足，难以领会更高深的秋风尘法。\n"}
    end

    test "三项全满足则放行" do
      assert QiufengChenfa.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert QiufengChenfa.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 35 / neili 10）" do
    test "返回 LPC 一致的消耗" do
      assert QiufengChenfa.practice_cost() == %{qi: 35, neili: 10}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qiufeng-chenfa") == QiufengChenfa
    end
  end
end

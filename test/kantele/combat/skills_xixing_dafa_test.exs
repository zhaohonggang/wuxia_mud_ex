defmodule Kantele.Combat.SkillsXixingDafaTest do
  @moduledoc """
  吸星大法学习门槛迁移（C 相位，xixing-dafa 真缺口补齐）。

  对照 `kungfu/skill/xixing-dafa.c`：
  - valid_learn: con>=30 / force>=100 /「未获 `can_learn/xixing-dafa/ren` 且 max_neili>0
    且 10<=等级<200」拒（散功诀窍门）；
  - 「性格为光明磊落则拒」为 alignment 门，本仓未建模，未迁移；
  - practice_skill 恒失败 → practice_cost 为 nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.XixingDafa

  defp stats(con, force, lvl),
    do: %{con: con, skills: %{"force" => force, "xixing-dafa" => lvl}}

  defp char(mn, marks \\ %{}),
    do: %{meta: %{vitals: %{max_neili: mn}, marks: marks}}

  describe "valid_learn/2 学习门槛（LPC con>=30 / force>=100）" do
    test "con < 30 被拒（心火如焚）" do
      assert XixingDafa.valid_learn(stats(29, 200, 0), char(0)) ==
               {:error, "你试着按照法门运转了一下内息，忽然觉得心火如焚，丹田却是一阵冰凉！\n"}
    end

    test "force < 100 被拒（基本内功修为不足）" do
      assert XixingDafa.valid_learn(stats(30, 99, 0), char(0)) ==
               {:error, "你的基本内功修为不足，难以修炼吸星大法。\n"}
    end
  end

  describe "valid_learn/2 散功诀窍门（LPC can_learn/xixing-dafa/ren + max_neili + 10<=lvl<200）" do
    test "无诀窍标记且 10<=等级<200 且有内力 → 拒" do
      assert XixingDafa.valid_learn(stats(30, 200, 50), char(1000)) ==
               {:error, "你没有按照吸星大法的诀窍将内力散去，现在还不" <> "敢妄自继续修行大法。\n"}
    end

    test "有诀窍标记则放行" do
      assert XixingDafa.valid_learn(
               stats(30, 200, 50),
               char(1000, %{"can_learn/xixing-dafa/ren" => 1})
             ) == :ok
    end

    test "等级 < 10 放行（尚未入门）" do
      assert XixingDafa.valid_learn(stats(30, 200, 9), char(1000)) == :ok
    end

    test "等级 >= 200 放行（已过门槛区间）" do
      assert XixingDafa.valid_learn(stats(30, 200, 200), char(1000)) == :ok
    end

    test "max_neili 为 0 放行（LPC 以 max_neili 真值作前置）" do
      assert XixingDafa.valid_learn(stats(30, 200, 50), char(0)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert XixingDafa.valid_learn(stats(30, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert XixingDafa.valid_learn(stats(30, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学或从 exert 增加熟练度" do
      assert XixingDafa.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("xixing-dafa") == XixingDafa
    end
  end
end

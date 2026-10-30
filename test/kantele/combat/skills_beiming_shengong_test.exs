defmodule Kantele.Combat.SkillsBeimingShengongTest do
  @moduledoc """
  北冥神功学习门槛迁移（C 相位，beiming-shengong 真缺口补齐）。

  对照 `kungfu/skill/beiming-shengong.c`：
  - valid_learn: 「无性且等级>49」拒 / int>=32 / con>=24；
  - practice_skill 恒失败 → practice_cost 为 nil（只能学不能练）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BeimingShengong

  defp stats(int, con, lvl),
    do: %{int: int, con: con, skills: %{"beiming-shengong" => lvl}}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛（LPC 无性&lvl>49 / int>=32 / con>=24）" do
    test "无性且等级 > 49 被拒" do
      assert BeimingShengong.valid_learn(stats(40, 30, 50), char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会高深的北冥神功。\n"}
    end

    test "无性但等级 <= 49 可通过性别门" do
      assert BeimingShengong.valid_learn(stats(40, 30, 49), char("无性")) == :ok
    end

    test "int < 32 被拒（艰深无比）" do
      assert BeimingShengong.valid_learn(stats(31, 30, 10), char("男性")) ==
               {:error, "你觉得北冥神功艰深无比，难以领会。\n"}
    end

    test "con < 24 被拒（眼前一黑）" do
      assert BeimingShengong.valid_learn(stats(40, 23, 10), char("男性")) ==
               {:error, "你试着运转了一下内力，眼前登时一黑！\n"}
    end

    test "三项全满足则放行" do
      assert BeimingShengong.valid_learn(stats(32, 24, 10), char("女性")) == :ok
    end

    test "character 为 nil 时按男性处理，性别门不触发" do
      assert BeimingShengong.valid_learn(stats(40, 30, 200), nil) == :ok
    end

    test "character 无 meta/env 时按男性处理" do
      assert BeimingShengong.valid_learn(stats(40, 30, 200), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学不能练" do
      assert BeimingShengong.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("beiming-shengong") == BeimingShengong
    end
  end
end

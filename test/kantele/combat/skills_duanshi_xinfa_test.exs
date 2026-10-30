defmodule Kantele.Combat.SkillsDuanshiXinfaTest do
  @moduledoc """
  段氏心法学习门槛迁移（C 相位，duanshi-xinfa 真缺口补齐）。

  对照 `kungfu/skill/duanshi-xinfa.c`：
  - valid_learn: 仅「无性且等级>49」拒，其余放行；
  - practice_skill 恒失败 → practice_cost 为 nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DuanshiXinfa

  defp stats(lvl), do: %{skills: %{"duanshi-xinfa" => lvl}}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛（LPC 无性&lvl>49）" do
    test "无性且等级 > 49 被拒" do
      assert DuanshiXinfa.valid_learn(stats(50), char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会高深的段氏心法。\n"}
    end

    test "无性但等级 <= 49 可通过" do
      assert DuanshiXinfa.valid_learn(stats(49), char("无性")) == :ok
    end

    test "男性无门槛" do
      assert DuanshiXinfa.valid_learn(stats(500), char("男性")) == :ok
    end

    test "女性无门槛" do
      assert DuanshiXinfa.valid_learn(stats(500), char("女性")) == :ok
    end

    test "character 为 nil 时按男性处理，恒放行" do
      assert DuanshiXinfa.valid_learn(stats(500), nil) == :ok
    end

    test "character 无 meta/env 时按男性处理" do
      assert DuanshiXinfa.valid_learn(stats(500), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学不能练" do
      assert DuanshiXinfa.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("duanshi-xinfa") == DuanshiXinfa
    end
  end
end

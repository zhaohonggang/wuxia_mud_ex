defmodule Kantele.Combat.SkillsYijinjingTest do
  @moduledoc """
  易筋经神功学习门槛迁移（C 相位，yijinjing 真缺口补齐）。

  对照 `kungfu/skill/yijinjing.c`：
  - valid_learn: force>=100 / force>=yijinjing / 必须男性
    （gender 走 meta.env[:gender]，records.apply_to_character 写入，默认「男性」）；
  - practice_skill 返回失败，只能学不能练 → practice_cost() == nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.Yijinjing

  defp stats(force, yijinjing),
    do: %{skills: %{"force" => force, "yijinjing" => yijinjing}}

  defp char_with_gender(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛" do
    test "force < 100 被拒（基本内功火候不够）" do
      assert Yijinjing.valid_learn(stats(50, 50), char_with_gender("男性")) ==
               {:error, "你的基本内功火候不够，无法学习易筋经神功！\n"}
    end

    test "force < yijinjing 被拒（基本内功水平不够）" do
      assert Yijinjing.valid_learn(stats(100, 150), char_with_gender("男性")) ==
               {:error, "你的基本内功水平不够，难以领悟更高深的易筋经神功！\n"}
    end

    test "女性被拒（必须男性）" do
      assert Yijinjing.valid_learn(stats(100, 50), char_with_gender("女性")) ==
               {:error, "你不是男性，无法练习易筋经神功。\n"}
    end

    test "全部满足则放行" do
      assert Yijinjing.valid_learn(stats(100, 50), char_with_gender("男性")) == :ok
    end

    test "character 无 meta/env 时默认男性（放行）" do
      assert Yijinjing.valid_learn(stats(100, 50), %{}) == :ok
    end

    test "character 为 nil 时默认男性（放行）" do
      assert Yijinjing.valid_learn(stats(100, 50), nil) == :ok
    end
  end

  describe "practice_cost（只能学不能练）" do
    test "返回 nil" do
      assert Yijinjing.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("yijinjing") == Yijinjing
    end
  end
end

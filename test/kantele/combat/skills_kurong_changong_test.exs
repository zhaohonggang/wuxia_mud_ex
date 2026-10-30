defmodule Kantele.Combat.SkillsKurongChangongTest do
  @moduledoc """
  枯荣禅功学习门槛迁移（C 相位，kurong-changong 真缺口补齐）。

  对照 `kungfu/skill/kurong-changong.c`：
  - valid_learn: 「无性」**无条件**拒绝（不看等级）；
  - practice_skill 恒失败 → practice_cost 为 nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.KurongChangong

  defp stats(lvl), do: %{skills: %{"kurong-changong" => lvl}}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛（LPC 无性无条件拒）" do
    test "无性且等级 0 也被拒（与其它内功不同，无 lvl>49 条件）" do
      assert KurongChangong.valid_learn(stats(0), char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会枯荣禅功。\n"}
    end

    test "无性且等级很高同样被拒" do
      assert KurongChangong.valid_learn(stats(500), char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会枯荣禅功。\n"}
    end

    test "男性无门槛" do
      assert KurongChangong.valid_learn(stats(500), char("男性")) == :ok
    end

    test "女性无门槛" do
      assert KurongChangong.valid_learn(stats(500), char("女性")) == :ok
    end

    test "character 为 nil 时按男性处理，放行" do
      assert KurongChangong.valid_learn(stats(500), nil) == :ok
    end

    test "character 无 meta/env 时按男性处理" do
      assert KurongChangong.valid_learn(stats(500), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学不能练" do
      assert KurongChangong.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("kurong-changong") == KurongChangong
    end
  end
end

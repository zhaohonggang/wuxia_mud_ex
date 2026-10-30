defmodule Kantele.Combat.SkillsMiaojiaNeigongTest do
  @moduledoc """
  苗家内功学习门槛迁移（C 相位，miaojia-neigong 真缺口补齐）。

  对照 `kungfu/skill/miaojia-neigong.c`：
  - valid_learn: 「无性且等级>49」拒，其余放行；
  - practice_skill 恒失败 → practice_cost 为 nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.MiaojiaNeigong

  defp stats(lvl), do: %{skills: %{"miaojia-neigong" => lvl}}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛（LPC 无性&lvl>49）" do
    test "无性且等级 > 49 被拒" do
      assert MiaojiaNeigong.valid_learn(stats(50), char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会高深的苗家内功。\n"}
    end

    test "无性但等级 <= 49 可通过" do
      assert MiaojiaNeigong.valid_learn(stats(49), char("无性")) == :ok
    end

    test "男性无门槛" do
      assert MiaojiaNeigong.valid_learn(stats(500), char("男性")) == :ok
    end

    test "女性无门槛" do
      assert MiaojiaNeigong.valid_learn(stats(500), char("女性")) == :ok
    end

    test "character 为 nil 时按男性处理，恒放行" do
      assert MiaojiaNeigong.valid_learn(stats(500), nil) == :ok
    end

    test "character 无 meta/env 时按男性处理" do
      assert MiaojiaNeigong.valid_learn(stats(500), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学不能练" do
      assert MiaojiaNeigong.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("miaojia-neigong") == MiaojiaNeigong
    end
  end
end

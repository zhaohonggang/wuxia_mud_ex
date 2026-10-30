defmodule Kantele.Combat.SkillsSankuShengongTest do
  @moduledoc """
  三苦神功学习门槛迁移（C 相位，sanku-shengong 真缺口补齐）。

  对照 `kungfu/skill/sanku-shengong.c`：
  - valid_learn: force>=40 / 「无性且等级>49」拒（先查基本内功）；
  - practice_skill 恒失败 → practice_cost 为 nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.SankuShengong

  defp stats(force, lvl),
    do: %{skills: %{"force" => force, "sanku-shengong" => lvl}}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛（LPC force>=40 / 无性&lvl>49）" do
    test "force < 40 被拒（基本内功太差）" do
      assert SankuShengong.valid_learn(stats(39, 10), char("男性")) ==
               {:error, "你的基本内功太差了。\n"}
    end

    test "force 不足时优先报内功门槛（先于性别门）" do
      assert SankuShengong.valid_learn(stats(0, 200), char("无性")) ==
               {:error, "你的基本内功太差了。\n"}
    end

    test "无性且等级 > 49 被拒（唐门不收）" do
      assert SankuShengong.valid_learn(stats(100, 50), char("无性")) ==
               {:error, "唐门不要你这种无根无性的人，你无法领会高深的三苦神功。\n"}
    end

    test "无性但等级 <= 49 可通过性别门" do
      assert SankuShengong.valid_learn(stats(100, 49), char("无性")) == :ok
    end

    test "两项全满足则放行" do
      assert SankuShengong.valid_learn(stats(40, 10), char("男性")) == :ok
    end

    test "character 为 nil 时按男性处理，性别门不触发" do
      assert SankuShengong.valid_learn(stats(100, 300), nil) == :ok
    end

    test "character 无 meta/env 时按男性处理" do
      assert SankuShengong.valid_learn(stats(100, 300), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学不能练" do
      assert SankuShengong.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("sanku-shengong") == SankuShengong
    end
  end
end

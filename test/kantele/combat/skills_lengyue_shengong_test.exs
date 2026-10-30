defmodule Kantele.Combat.SkillsLengyueShengongTest do
  @moduledoc """
  冷月神功学习门槛迁移（C 相位，lengyue-shengong 真缺口补齐）。

  对照 `kungfu/skill/lengyue-shengong.c`：
  - valid_learn: 「无性且 `lenyue-shengong` 等级>49」拒。LPC 把技能名拼错（少一个 `g`），
    该技能不存在、恒返回 0，故门**永不触发**。本实现照抄同一错误 id，行为与 LPC 一致。
  - practice_skill 恒失败 → practice_cost 为 nil。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LengyueShengong

  defp stats(lvl), do: %{skills: %{"lengyue-shengong" => lvl}}

  defp stats_with_typo(typo_lvl),
    do: %{skills: %{"lengyue-shengong" => 0, "lenyue-shengong" => typo_lvl}}

  defp char(gender), do: %{meta: %{env: %{gender: gender}}}

  describe "valid_learn/2 学习门槛（LPC 门因拼写错误失效）" do
    test "无性且本技能等级很高，仍放行（门失效，LPC bug 保真）" do
      assert LengyueShengong.valid_learn(stats(500), char("无性")) == :ok
    end

    test "无性且等级 0 放行" do
      assert LengyueShengong.valid_learn(stats(0), char("无性")) == :ok
    end

    test "查询的是拼错的 lenyue-shengong：该 id 达标才会拒（证明 bug 已照抄）" do
      assert LengyueShengong.valid_learn(stats_with_typo(50), char("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会高深的冷月神功。\n"}
    end

    test "拼错 id 达标但角色非无性时放行" do
      assert LengyueShengong.valid_learn(stats_with_typo(50), char("男性")) == :ok
    end

    test "character 为 nil 时按男性处理" do
      assert LengyueShengong.valid_learn(stats(500), nil) == :ok
    end

    test "character 无 meta/env 时按男性处理" do
      assert LengyueShengong.valid_learn(stats(500), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 恒失败）" do
    test "返回 nil，表示只能学不能练" do
      assert LengyueShengong.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("lengyue-shengong") == LengyueShengong
    end
  end
end

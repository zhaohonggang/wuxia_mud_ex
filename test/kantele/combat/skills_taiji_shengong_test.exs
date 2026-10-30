defmodule Kantele.Combat.SkillsTaijiShengongTest do
  @moduledoc """
  太极神功学习门槛迁移（C 相位，taiji-shengong 真缺口补齐）。

  对照 `kungfu/skill/taiji-shengong.c`：
  - valid_learn: 无性&taoism>19 / force>=100 / taoism>=100 / (taoism<320 & taoism<level)；
  - practice_skill 返回失败（只能学不能练）。性别走 meta.env[:gender]（默认「男性」）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.TaijiShengong

  defp stats(force, taoism, taiji),
    do: %{skills: %{"force" => force, "taoism" => taoism, "taiji-shengong" => taiji}}

  defp char_with_gender(g), do: %{meta: %{env: %{gender: g}}}

  describe "valid_learn/2 学习门槛（LPC 无性&taoism>19 / force>=100 / taoism>=100 / (taoism<320 & taoism<level)）" do
    test "无性 & taoism>19 被拒（阴阳不调）" do
      assert TaijiShengong.valid_learn(stats(200, 100, 50), char_with_gender("无性")) ==
               {:error, "你无根无性，阴阳不调，难以领会高深的太极神功。\n"}
    end

    test "force < 100 被拒（内功火候不够）" do
      assert TaijiShengong.valid_learn(stats(50, 200, 50), char_with_gender("男性")) ==
               {:error, "你的基本内功火候还不够。\n"}
    end

    test "taoism < 100 被拒（道家心法领悟太浅）" do
      assert TaijiShengong.valid_learn(stats(200, 50, 50), char_with_gender("男性")) ==
               {:error, "你对道家心法领悟的太浅，无法理解太极神功。\n"}
    end

    test "taoism<320 且 taoism<level 被拒（道学理解不够）" do
      assert TaijiShengong.valid_learn(stats(200, 100, 200), char_with_gender("男性")) ==
               {:error, "你对道学心法的理解不够，难以锻炼更深厚的太极神功。\n"}
    end

    test "四项全满足则放行" do
      assert TaijiShengong.valid_learn(stats(200, 400, 50), char_with_gender("男性")) == :ok
    end

    test "character 为 nil 时性别按默认男性处理（其余门槛仍生效）" do
      assert TaijiShengong.valid_learn(stats(200, 400, 50), nil) == :ok
    end

    test "character 无 meta/env 时性别按默认男性处理" do
      assert TaijiShengong.valid_learn(stats(200, 400, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 返回失败，只能学不能练）" do
    test "返回 nil" do
      assert TaijiShengong.practice_cost() == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("taiji-shengong") == TaijiShengong
    end
  end
end

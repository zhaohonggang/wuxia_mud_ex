defmodule Kantele.Combat.SkillsHunyuanYiqiTest do
  @moduledoc """
  混元一气功学习门槛迁移（C 相位，valid_learn 保真）。

  对照 `kungfu/skill/hunyuan-yiqi.c`：
  - 已婚（`couple/have_couple`）/ 非男性 / 禅宗心法不足 / 内功火候不足 被拒；
  - 「屡犯僧戒（`guilty`）」按 `meta.guilty` 实装（与 buddhism.ex 同款 no-op：端口未建模写入路径 → 恒 0）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.HunyuanYiqi

  defp stats(buddhism, force, level),
    do: %{skills: %{"buddhism" => buddhism, "force" => force, "hunyuan-yiqi" => level}}

  defp char(extra), do: %{meta: Map.merge(%{}, extra)}

  describe "valid_learn/2 学习门槛（LPC 逐条保真）" do
    test "已婚被拒（破了色戒）" do
      assert HunyuanYiqi.valid_learn(stats(0, 0, 0), char(%{spouse: %{id: "x"}})) ==
               {:error, "你已经破了色戒，无法再学习混元一气功！\n"}
    end

    test "非男性被拒（非童男之体）" do
      assert HunyuanYiqi.valid_learn(stats(0, 0, 0), char(%{env: %{gender: "女性"}})) ==
               {:error, "你非童男之体，不能练习混元一气功。\n"}
    end

    test "基本内功火候不足被拒" do
      assert HunyuanYiqi.valid_learn(stats(300, 10, 0), nil) ==
               {:error, "你的基本内功火候还不够，无法学习混元一气功。\n"}
    end

    test "guilty>0 被拒（屡犯僧戒）" do
      assert HunyuanYiqi.valid_learn(stats(300, 100, 0), char(%{guilty: 5})) ==
               {:error, "你屡犯僧家数戒，无法领会更高深的混元一气功。\n"}
    end

    test "guilty=0 且其余门槛满足则放行" do
      assert HunyuanYiqi.valid_learn(stats(300, 100, 0), char(%{guilty: 0})) == :ok
    end

    test "character 为 nil 时 guilty 默认 0（兜底放行）" do
      assert HunyuanYiqi.valid_learn(stats(300, 100, 0), nil) == :ok
    end

    test "无 meta 的空 character 也能判定（guilty 兜底 0）" do
      assert HunyuanYiqi.valid_learn(stats(300, 100, 0), %{}) == :ok
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("hunyuan-yiqi") == HunyuanYiqi
    end
  end
end

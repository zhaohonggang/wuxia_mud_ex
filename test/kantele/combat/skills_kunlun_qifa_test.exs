defmodule Kantele.Combat.SkillsKunlunQifaTest do
  @moduledoc """
  昆仑器法学习门槛迁移（C 相位，kunlun-qifa 真缺口补齐）。

  对照 `kungfu/skill/kunlun-qifa.c`：
  - valid_learn: throwing>=50 / throwing>=kunlun-qifa（无 max_neili/force 门槛）；
  - practice_skill 扣 qi 70 / neili 50（须持暗器，由 practice 流程把关）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.KunlunQifa

  defp stats(throwing, kunlun),
    do: %{skills: %{"throwing" => throwing, "kunlun-qifa" => kunlun}}

  describe "valid_learn/2 学习门槛（LPC throwing>=50 / throwing>=self）" do
    test "throwing < 50 被拒（暗器技能不够娴熟）" do
      assert KunlunQifa.valid_learn(stats(10, 50), %{meta: %{vitals: %{max_neili: 2000}}}) ==
               {:error, "你的暗器技能不够娴熟。\n"}
    end

    test "throwing < kunlun-qifa 被拒（基本暗器水平有限）" do
      assert KunlunQifa.valid_learn(stats(100, 150), %{meta: %{vitals: %{max_neili: 2000}}}) ==
               {:error, "你的基本暗器水平有限，难以领会更精妙的昆仑器法。\n"}
    end

    test "两项全满足则放行（character 任意值均忽略）" do
      assert KunlunQifa.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 为 nil 仍放行" do
      assert KunlunQifa.valid_learn(stats(200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 仍放行" do
      assert KunlunQifa.valid_learn(stats(200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 70 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert KunlunQifa.practice_cost() == %{qi: 70, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("kunlun-qifa") == KunlunQifa
    end
  end
end

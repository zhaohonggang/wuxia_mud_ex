defmodule Kantele.Combat.SkillsBaguaBiaoTest do
  @moduledoc """
  八卦镖诀学习门槛迁移（C 相位，bagua-biao 真缺口补齐）。

  对照 `kungfu/skill/bagua-biao.c`：
  - valid_learn: throwing>=10 / throwing>=bagua-biao；
  - practice_skill 扣 qi 70 / neili 50。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BaguaBiao

  defp stats(throwing, bagua),
    do: %{skills: %{"throwing" => throwing, "bagua-biao" => bagua}}

  describe "valid_learn/2 学习门槛（LPC throwing>=10 / throwing>=self）" do
    test "throwing < 10 被拒（暗器技能不够娴熟）" do
      assert BaguaBiao.valid_learn(stats(5, 0), nil) ==
               {:error, "你的暗器技能不够娴熟。\n"}
    end

    test "throwing < bagua-biao 被拒（基本暗器水平有限）" do
      assert BaguaBiao.valid_learn(stats(50, 60), nil) ==
               {:error, "你的基本暗器水平有限，难以领会更精妙的八卦镖诀。\n"}
    end

    test "两项全满足则放行" do
      assert BaguaBiao.valid_learn(stats(50, 40), nil) == :ok
    end

    test "character 为 nil 不影响（无 max_neili 门槛）" do
      assert BaguaBiao.valid_learn(stats(50, 40), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 70 / neili 50）" do
    test "返回 LPC 一致的消耗" do
      assert BaguaBiao.practice_cost() == %{qi: 70, neili: 50}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("bagua-biao") == BaguaBiao
    end
  end
end

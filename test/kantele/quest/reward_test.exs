defmodule Kantele.Quest.RewardTest do
  use ExUnit.Case, async: true

  alias Kantele.Quest
  alias Kantele.Quest.Reward

  test "base 各类型有基础档且可加未知类型" do
    assert Reward.base("kill").exp >= Reward.base("letter").exp
    assert is_map(Reward.base("unknown"))
  end

  test "scale 按 level 每级 +10%、连续前 10 次每次 +5%" do
    assert Reward.scale(%{exp: 100}, 1, 0) == %{exp: 110}
    assert Reward.scale(%{exp: 100}, 1, 1) == %{exp: 115}
    assert Reward.scale(%{exp: 100}, 3, 1) == %{exp: 135}
    assert Reward.scale(%{exp: 100}, 5, 20) == %{exp: 200}
  end

  test "merge 同键求和、容忍 nil" do
    assert Reward.merge(%{exp: 100, coins: 5}, %{exp: 50, score: 2}) == %{
             exp: 150,
             coins: 5,
             score: 2
           }

    assert Reward.merge(nil, %{coins: 1}) == %{coins: 1}
  end

  test "milestone_bonus 按 tier 给额外档位" do
    assert Reward.milestone_bonus(30).gongxian == 30
    assert Reward.milestone_bonus(nil) == %{}
  end

  test "final：任务在办中按类型/难度/连续放大并叠加 turn_rewards" do
    {:ok, state} = Quest.set_todo(Quest.new(), %{file: "kill-quest", type: "kill", level: 3, kill: ["yezhu"]})

    final = Reward.final(state, "kill-quest", %{coins: 100})

    assert final.coins == 100
    assert final.gongxian == 20
    assert final.exp == 405
    assert final.weiwang == 3
  end

  test "final：quest_count 影响连续放大" do
    state = %{Quest.new() | quest_count: 9}

    {:ok, state} = Quest.set_todo(state, %{file: "kill-quest", type: "kill", level: 1, kill: ["yezhu"]})

    # streak+1 = 10 → +50%；level 1 → +10% → factor 1.6；exp 300*1.6 = 480
    assert Reward.final(state, "kill-quest", %{}) == %{
             exp: 480,
             potential: 192,
             score: 96,
             weiwang: 3,
             gongxian: 24
           }
  end

  test "final：任务不在在办/quest_id 为空时原样返回 turn_rewards" do
    state = Quest.new()
    assert Reward.final(state, "none", %{coins: 5}) == %{coins: 5}
    assert Reward.final(state, nil, %{coins: 5}) == %{coins: 5}
    assert Reward.final(state, "none", nil) == %{}
  end

  test "final：连续完成命中里程碑时叠加 milestone_bonus" do
    state = %{Quest.new() | quest_count: 29}

    {:ok, state} = Quest.set_todo(state, %{file: "kill-quest", type: "kill", level: 1, kill: ["yezhu"]})

    final = Reward.final(state, "kill-quest", %{})

    # streak+1 = 30 命中阶梯 → bonus exp 600/pot 300/score 120/gongxian 30
    # 基础放大 factor 1.6 → 480/192/96/3/24 再叠加 bonus
    assert final == %{exp: 1080, potential: 492, score: 216, weiwang: 3, gongxian: 54}
  end
end
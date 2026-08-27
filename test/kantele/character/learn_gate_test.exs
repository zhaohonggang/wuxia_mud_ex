defmodule Kantele.Character.LearnGateTest do
  use ExUnit.Case, async: false

  alias Kantele.Character.LearnGate
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  describe "b3 耗精公式（learn.c:117-122）" do
    test "(100 + skill*2) / int；0 级初学 ×2" do
      stats = Stats.new() |> Map.put(:int, 20)

      # 10 级：div(120, 20) = 6
      stats_10 = Map.put(stats, :skills, %{"sword" => 10})
      assert LearnGate.jing_cost(stats_10, "sword") == 6

      # 0 级初学：div(100, 20) = 5 ×2 = 10（空 skills 表）
      stats_zero = Map.put(stats, :skills, %{})
      assert LearnGate.jing_cost(stats_zero, "sword") == 10
    end

    test "开关开启时精不足即停，pay_level 扣精" do
      Application.put_env(:ex_venture, :enable_jing_learn_cost, true)
      on_exit(fn -> Application.delete_env(:ex_venture, :enable_jing_learn_cost) end)

      # 空 skills：sword 0 级初学，耗精 10
      stats = Stats.new() |> Map.put(:int, 20) |> Map.put(:skills, %{})
      vitals = %Vitals{Vitals.new() | jing: 5, max_jing: 120}

      assert {:halt, _} = LearnGate.level_gate(vitals, stats, "sword")

      rich_vitals = %Vitals{Vitals.new() | jing: 100}
      assert :ok = LearnGate.level_gate(rich_vitals, stats, "sword")

      {vitals2, stats2} = LearnGate.pay_level(rich_vitals, stats, "sword")
      assert vitals2.jing == 90
      assert stats2.learned_points == LearnGate.learn_cost()
    end

    test "开关默认关闭：不扣精、精低不停" do
      Application.delete_env(:ex_venture, :enable_jing_learn_cost)

      stats = Stats.new()
      vitals = %Vitals{Vitals.new() | jing: 1}

      assert :ok = LearnGate.level_gate(vitals, stats, "sword")
      {vitals2, _} = LearnGate.pay_level(vitals, stats, "sword")
      assert vitals2.jing == 1
    end
  end

  describe "b4 经验门（skill.c:278）" do
    test "(lvl+1)³/10 <= combat_exp 判定下一级" do
      # 默认 combat_exp 1000：9→10 级需 100 ✓，21→22 需 1064 ✗
      stats = Map.put(Stats.new(), :skills, %{"sword" => 9})
      assert LearnGate.can_improve?(stats, "sword")

      stats_21 = Map.put(stats, :skills, %{"sword" => 21})
      refute LearnGate.can_improve?(stats_21, "sword")
    end

    test "开关默认关闭时 snapshot_gate 不拦经验" do
      Application.delete_env(:ex_venture, :enable_exp_gate)

      stats =
        Stats.new()
        |> Map.put(:combat_exp, 0)
        |> Map.put(:skills, %{"sword" => 99})

      assert {:error, _} = LearnGate.snapshot_gate(%{stats | potential: 0}, "sword")
      refute LearnGate.exp_gate_enabled?()

      # 潜能充足时即便等级远超经验也放行
      assert :ok = LearnGate.snapshot_gate(%{stats | potential: 100}, "sword")
    end

    test "开关开启后拦截并提示" do
      Application.put_env(:ex_venture, :enable_exp_gate, true)
      on_exit(fn -> Application.delete_env(:ex_venture, :enable_exp_gate) end)

      stats =
        Stats.new()
        |> Map.put(:combat_exp, 0)
        |> Map.put(:skills, %{"sword" => 99})

      assert {:error, "也许是缺乏实战经验，你对师父的回答总是无法领会。\n"} =
               LearnGate.snapshot_gate(%{stats | potential: 100}, "sword")
    end
  end

  describe "b5 内功互斥（learn.c can_learn）" do
    test "柳溪内功不接受任何其他内功共存" do
      refute Kantele.Combat.Skills.LiuxiNeigong.valid_force("any-other")
    end

    test "已学内功拒绝新技能（即使新技能非内功类）" do
      stats = Map.put(Stats.new(), :skills, %{"liuxi-neigong" => 30})

      assert LearnGate.force_conflict(stats, "liuxin-jian") == "liuxi-neigong"
    end

    test "未习得其他内功时不冲突" do
      stats = Stats.new()
      assert LearnGate.force_conflict(stats, "liuxi-neigong") == nil
    end
  end

  describe "b1 潜能池" do
    test "available_potential = potential - learned_points，nil 安全" do
      assert Stats.new() |> Stats.available_potential() == 100

      spent =
        Stats.new()
        |> Stats.spend_potential(6)

      assert spent.potential == 100
      assert spent.learned_points == 6
      assert Stats.available_potential(spent) == 94

      bare = %Stats{}
      assert Stats.available_potential(bare) == 0
    end
  end
end
